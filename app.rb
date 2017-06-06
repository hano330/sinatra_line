require "bundler"
Bundler.require(:default, :production)

require "rack-flash"
require "tempfile"
require "sinatra/reloader"

class MineApp < Sinatra::Base
  configure do
    # DB設定ファイルの読み込み
    #db/database.ymlにしないならどうやって読み込むかわからなくなった・・・
    ActiveRecord::Base.configurations = YAML.load_file("db/database.yml")
    ActiveRecord::Base.establish_connection(:development)
  end

  set :public_folder, File.dirname(__FILE__) + "/public"

  #セッション開始
  enable :sessions
  #これでFlashが使える
  use Rack::Flash

  before do
    set_current_user
  end

  helpers Sinatra::ContentFor
  helpers do
    #メッセージ送信の際にScriptを書いても無視するためのエスケープ処理
    #書き方は「おまじない」的なものとして教えられた
    include Rack::Utils
    alias_method :h, :escape_html

    def login?
      session[:user_id].present?
    end

    def set_current_user
      @current_user = User.find_by(id: session[:user_id]) if login?
    end

  end


  #トップページまたはログイン後の画面へ
  get "/" do
    if login?
      session[:rid] = nil
      @friends = {}
      @talkrooms = {}
      @requesteds = []

      #友達

      #@current_userのtalkroomの情報を手に入れる
      #下の酷似している@current_user_talkroomsを見ればわかるが、関連付けを利用してデータを引っ張ってきた場合、
      #idsとidだけを引っ張ってきたらuniqが使えるが、そうでなければdisticntが正解。
      #後で記事で書く。ちなみに、uniqを使わなければ[67,67,67]となるが、それは中間テーブルであるposts
      #で3回ポストしているから。


      @current_user_talkrooms = @current_user.talkrooms.ids.uniq
      #現在のユーザーの友達関係を情報を集める
      @friend_relationships = @current_user.relationships.where(status: "friends")
      #一人一人の友達関係による友達のIDから友達の一般情報とお互いがトークしているトークルームIDを見つける
      @friend_relationships.each do |friend_relationship|
        friend_info = User.find(friend_relationship.friend_id)
        @friend_info = []
        @friend_info.push(friend_info.name)
        @friend_info.push(friend_info.profile_url)
        @friend_info.push(friend_info.id)
        @friend_talkrooms = friend_info.talkrooms.ids.uniq
        if @friend_talkrooms.present?
          #友達がトークルームを持っていれば、自分のトークルームとマッチングする
          @match_talkroom_ids = @friend_talkrooms & @current_user_talkrooms
          if @match_talkroom_ids.present?
            i = 0
            @match_talkroom_ids.each do |match_talkroom_id|
              #マッチするトークルームがあれば、第三者がいないかチェックする
              max = @match_talkroom_ids.size
              @other_member_check = Post.where.not(user_id: @current_user.id ).where.not(user_id: friend_info.id).where(talkroom_id: match_talkroom_id)
              if @other_member_check.present? && i < max - 1
                #他のメンバーがいるならこのトークルームは無視
                i += 1
                next
              elsif @other_member_check == []
                #居ないならそれが1対1のトークルーム
                @friends[match_talkroom_id] = @friend_info
                break
              else
                #全てのトークルームに第三者がいれば、1対1のトークルームはない
                @friends["no_room_#{friend_info.id}"] = @friend_info
              end
            end
          else
            #マッチするトークルームがない
            @friends["no_room_#{friend_info.id}"] = @friend_info
          end
        else
          #友達がトークルームを一つも持っていないno_room + 友達のIDをキーにする
          @friends["no_room_#{friend_info.id}"] = @friend_info
        end
      end
      #トーク

      #@current_userのtalkroomの情報を手に入れる
      @current_user_talkrooms = @current_user.talkrooms.distinct

      @current_user_talkrooms.each do |current_user_talkroom|
        @talk_users = current_user_talkroom.users.where.not(id: @current_user.id).distinct
        #トークルーム毎にトーク相手を入れる配列を初期化
        @talk_with = []
        @talk_users.each do |talk_user|
          #話し相手の名前を配列に挿入
          @talk_with.push(talk_user.name)
        end
        @talkroom_info = []
        #新しいメッセージまたは最新のメッセージを取得
        @newpost = Post.where(talkroom_id: current_user_talkroom.id, kidoku: nil).where.not(user_id: @current_user.id).last
        if @newpost.present?
          @talkroom_info.push(@newpost.body)
          @talkroom_info.push(@newpost.created_at)
          @talkroom_info.push("new")
        else
          @latestpost = Post.where(talkroom_id: current_user_talkroom.id).last
          @talkroom_info.push(@latestpost.body)
          @talkroom_info.push(@latestpost.created_at)
        end
        #talkroom_info配列の最初はトーク相手の配列を入れる
        @talkroom_info.unshift(@talk_with)
        @talkrooms[current_user_talkroom.id] = @talkroom_info
      end

      #リクエスト
      @requesteds_relationships = Relationship.where(friend_id: @current_user.id, status: "requesting")
      @requesteds_relationships.each do |requesteds_relationship|
        requested_info = User.find(requesteds_relationship.user_id)
        @requesteds.push(requested_info)
      end

      erb :home
    else
      erb :index
    end
  end

  #新規登録画面へ
  get "/signup" do
    erb :signup
  end

  #新規登録画面へ
  post "/register" do
    return redirect '/' if login?

    #has_secure_passwordを利用するためuser.passwordにパスワードを入れる
    user = User.create(name: params[:name], password: params[:password])

    #VaridationでIDとPWが入力されたかどうかをチェック
    if user.valid?
      flash[:notice] = "ユーザー登録が完了しました。ログインしてください。"
      erb :login
    else
      flash[:notice] = "IDとPWを入力して登録ボタンを押してください。"
      erb :signup
    end
  end

  #ログイン画面
  get "/login" do
    return redirect "/" if login?
    erb :login
  end

  #ログイン
  post "/login" do
    return redirect "/" if login?

    user = User.find_by(name: params[:name])
    #userが存在し、userのpasswordが一致するか

    if user && user.authenticate(params[:password])
      session[:user_id] = user.id
      flash[:notice] = "ログインに成功しました。"
      redirect "/"
    else
      flash[:notice] = "ログインしてください。"
      erb :login
    end
  end

  post "/friend_search" do
    user = User.find_by(id: params[:id])
    @already_friend1 = Relationship.find_by(friend_id: params[:id], user_id: @current_user.id)
    @already_friend2 = Relationship.find_by(friend_id: @current_user.id, user_id: params[:id])
   if user && user != @current_user
     if @already_friend1.nil? && @already_friend2.nil?
       session[:perhaps_friend] = user
       flash[:notice] = "友達を見つけました。"
       redirect "/"
     else
       flash[:notice] = "IDが無効、または既に友達か、リクエストが送られています。"
       redirect "/"
     end
   else
     flash[:notice] = "IDが無効、または既に友達か、リクエストが送られています。"
     redirect "/"
   end
  end

  post "/delete" do
    @relationship = Relationship.find_by(user_id: params[:id], friend_id: @current_user.id)
    @relationship.destroy
    redirect "/"
  end

  post "/request" do
    #jQueryによるポストではリダイレクトしないらしい・・・
    session[:perhaps_friend] = nil
    @relationship = @current_user.relationships.create(friend_id: params[:id], status: "requesting")
    redirect "/"
  end

  post "/accept" do
    @relationship = Relationship.find_by(user_id: params[:id], friend_id: @current_user.id)
    @relationship.update(status: "friends")
    @relationship = @current_user.relationships.create(friend_id: params[:id], status: "friends")
    redirect "/"
  end

  post "/newphoto" do
    type = if params[:file][:type] == "image/png"
             "png"
           elsif params[:file][:type] == "image/jpeg"
             "jpeg"
           elsif params[:file][:type] == "image/gif"
             "gif"
           end

    file_address = "#{@current_user.id}.#{type}"

    #下記のコードはローカルで実行するなら有効（publicフォルダ下のimagesにどんどんアップロードした画像が保存される）
    save_path = "./public/images/#{file_address}"

    File.open(save_path, "wb") do |f|
      f.write params[:file][:tempfile].read
    end

    if @current_user.update(profile_url: file_address)
      flash[:notice] = "プロフィール写真の変更に成功しました。"
      redirect "/"
    else
      flash[:notice] = "プロフィール写真の変更に失敗しました。"
      redirect "/"
    end
  end

  get "/talk/room/:name/:rid" do
    session[:rid] = params[:rid]
    @to_user = User.find_by(name: params[:name])
    @my_posts = @current_user.posts.where(talkroom_id: session[:rid])
    @your_posts = Post.where(talkroom_id: session[:rid]).where.not(user_id: @current_user.id)
    @posts = @my_posts + @your_posts
    @posts = @posts.sort
    @your_posts.update_all(kidoku: 1)
    erb :talk if login?
  end

  post "/new" do
    if params[:body].present?
      @post = @current_user.posts.create(body: params[:body], talkroom_id: session[:rid])
    end
    redirect back
  end

  post "/logout" do
    session.clear
    flash[:notice] = "ログアウトしました。"
    redirect"/"
  end

end

class User < ActiveRecord::Base
  has_many :relationships
  has_many :posts
  has_many :talkrooms, through: :posts

  has_secure_password

  validates :name, presence: true
end

class Post < ActiveRecord::Base
  belongs_to :user
  belongs_to :talkroom
end

class Relationship < ActiveRecord::Base
  belongs_to :user
end

class Talkroom < ActiveRecord::Base
  has_many :posts
  has_many :users, through: :posts
end


