
require "active_record"
require "mysql2"
require "sinatra"
require "sinatra/content_for"
require "rack-flash"
#require "sinatra/reloader"

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

class Friend < ActiveRecord::Base
end

class Fadd < ActiveRecord::Base
end

before do
  set_current_user
  set_to_user
end

helpers do
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
    erb :home
  else
    erb :login
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

get "/masa" do
  erb :talk if login?
end