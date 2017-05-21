
require "active_record"
require "mysql2"
require "sinatra"
require "sinatra/content_for"
require "rack-flash"

# DB設定ファイルの読み込み
ActiveRecord::Base.configurations = YAML.load_file("./config/database.yml")
ActiveRecord::Base.establish_connection(:development)

#セッション開始
enable :sessions
#これでFlashが使える
use Rack::Flash


class User < ActiveRecord::Base

  has_secure_password

  #Validation
  validates :name, presence: true
  validates :password, presence: true

end

class Post < ActiveRecord::Base
end


before do
  set_current_user
end

helpers do
  def login?
    session[:user_id].present?
  end

  def set_current_user
    @current_user = User.find(session[:user_id]) if login?
  end
end


#トップページまたはログイン後の画面へ
get "/" do
  if login?
    erb :success
  else
    erb :index
  end
end

#新規登録画面へ
post "/signup" do
  return redirect "/" if login?
  erb :signup
end

#新規登録画面へ
post "/register" do
  return redirect '/' if login?

  @id = params[:id]
  @pw = params[:password]

  #has_secure_passwordを利用するためuser.passwordにパスワードを入れる
  user = User.create(name: @id, password: @pw)

  #VaridationでIDとPWが入力されたかどうかをチェック
  if user.valid?
    erb :login
  else
    erb :missignup
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

  user = User.find_by(name: params[:id])
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

get "/logout" do
  session.clear
  flash[:notice] = "ログアウトしました。"
  redirect"/"
end