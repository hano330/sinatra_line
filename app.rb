require "bundler"
Bundler.require

require "rack-flash"

class MineApp < Sinatra::Base
  configure do
    # DB設定ファイルの読み込み
    #db/database.ymlにしないならどうやって読み込むかわからなくなった・・・
    #ActiveRecord::Base.configurations = YAML.load_file("db/database.yml")
    ActiveRecord::Base.establish_connection(ENV["postgresql-flexible-24081"] || "postgres://mwvfdbywwseysv:3a1e0ca5ba219e2bf4e8aa6d1290fb01c71f565f335fcbf8701524eb676ae5e3@ec2-184-73-236-170.compute-1.amazonaws.com:5432/d3suersi6s7tmn")
  end

  #ローカルでやる場合はこれでok
  # set :public_folder, File.dirname(__FILE__) + "/public"
  set :public_folder, File.dirname(__FILE__) + "/public"

  #セッション開始
  enable :sessions
  #これでFlashが使える
  use Rack::Flash

  before do
    set_current_user
    set_to_user
  end

  helpers Sinatra::ContentFor
  helpers do
    #メッセージ送信の際にScriptを書いても無視するためのエスケープ処理
    #書き方は「おまじない」的なものとして教えられた
    include Rack::Utils
    alias_method :h, :escape_html

    def login?
      session[:user_name].present?
    end

    def talk?
      session[:to_name].present?
    end

    def set_current_user
      @current_user = User.find_by(name: session[:user_name]) if login?
    end

    def set_to_user
      @to_user = User.find_by(name: session[:to_name]) if talk?
    end
  end


  #トップページまたはログイン後の画面へ
  get "/" do
    if login?
      @friends = Friend.where(user_name: @current_user.name)
      @users = User.order(id: :desc)
      @reqs = Fadd.where(req_from: @current_user.name)
      @reqds = Fadd.where(req_to: @current_user.name)
      @i = 0
      @x = 0
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
      session[:user_name] = user.name
      flash[:notice] = "ログインに成功しました。"
      redirect "/"
    else
      flash[:notice] = "ログインしてください。"
      erb :login
    end
  end

  post "/logout" do
    session.clear
    flash[:notice] = "ログアウトしました。"
    redirect"/"
  end

  get "/hello/:name" do
    @to_user = User.find_by(name: params[:name])
    session[:to_user] = @to_user.name
    #@posts = Post.where("(user_id = ?) or (to_id = ?)", @current_user.id, session[:to_id])

    #相手による自分へのポストと自分からの相手へのポストを抽出し、日付順（id順になっているのかな）に並べる
    @myposts = Post.where(name: @current_user.name, sent_to: session[:to_user])
    @urposts = Post.where(name: session[:to_user], sent_to: @current_user.name)
    @posts = @myposts + @urposts
    @posts = @posts.sort
    @urposts.update_all(kidoku: 1)
    erb :talk if login?
  end

  post "/new" do
    Post.create(name: @current_user.name, body: params[:body], sent_to: session[:to_user])
    @to_user_name = session[:to_user]
    redirect "/hello/#{@to_user_name}"
  end

  post "/delete" do
    Post.find(params[:id]).destroy
  end

  post "/request" do
    Fadd.create(req_from: @current_user.name, req_to: params[:name])
    #jQueryによるポストではリダイレクトしないらしい・・・
    redirect "/"
  end

  post "/acceptreq" do
    Friend.create(user_name: @current_user.name, frie_name: params[:name])
    Friend.create(user_name: params[:name], frie_name: @current_user.name)
    done_req = Fadd.where(req_from: params[:name], req_to: @current_user.name)
    #destroyではだめでdestroy_allにしたら消えた。
    done_req.destroy_all
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

    # save_path = "./images/#{file_address}"

    photo = Photo.create(file_belongs: file_address file: params[:file])

    # File.open(photo.file, "wb") do |f|
    #   f.write params[:file][:tempfile].read
    # end

    # #File.openとFile.writeをつかって原始的にやってみる
    # photo = Photo.create(file_belongs: file_address)
    # File.open("test", "wb") do |f|
    #   f.write params[:file][:tempfile].read
    # end
    # photo.file = test

    if @current_user.update(profile_url: file_address)
      flash[:notice] = "プロフィール写真の変更に成功しました。"
      redirect "/mypage"
    else
      flash[:notice] = "プロフィール写真の変更に失敗しました。"
      redirect "/mypage"
    end
  end

  get "/mypage" do
    @photo = Photo.find_by(file_belongs: @current_user.profile_url)
    erb :mypage
  end
end

class User < ActiveRecord::Base
  has_secure_password

  #Validation
  validates :name, presence: true
end

class Post < ActiveRecord::Base
end

class Friend < ActiveRecord::Base
end

class Fadd < ActiveRecord::Base
end

class Photo < ActiveRecord::Base
end

