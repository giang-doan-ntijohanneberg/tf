require 'slim'
require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'

enable :sessions

get('/') do
    slim(:index)
end

get('/index') do
    slim(:index)
end

get('/spring_collection') do
    slim(:shop)
end

get('/gallery') do
    slim(:gallery)
end

get('/member') do
    slim(:member)
end

get('/showlogin') do
    slim(:login)
end

post('/login') do
    username = params[:username]
    password = params[:password]
    db = SQLite3::Database.new('db/test.db')
    db.results_as_hash = true
    result = db.execute("SELECT * FROM users WHERE username = ?", username).first
    pwdigest = result["pwdigest"]
    id = result["id"]
    if BCrypt::Password.new(pwdigest) == password
        session[:id] = id
        redirect('/main')
    else
        redirect('/')
        "Wrong password"
    end
end

post('/userslogin/new') do
    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]

    if (password == password_confirm)
        password_digest = BCRypt::Password.create(password)
        db = SQLite3::Database.new('db/test.db')
        db.execute("INSERT INTO users (username, pwdigest) VALUES (?,?)", username,password_digest)
        redirect('/')
    else
        redirect('/')
        "Lösenorden matchade inte"
    end
end
