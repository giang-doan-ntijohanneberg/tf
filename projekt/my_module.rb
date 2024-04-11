require 'slim'
require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'

module MyModule

    def require_login()
        if request.path_info != '/' && session[:id].nil? && !['/member', '/add', '/newmember', '/login', '/filter'].include?(request.path_info)
            redirect ('/')
        end
    end

    def connect_to_db(path)
        db = SQLite3::Database.new(path)
        db.results_as_hash = true
        return db
    end

    def connect_execute(query, *params)
        db = connect_to_db('db/projekt.db')
        db.execute(query, *params)
    end

    def fetch_table()
        seasons = connect_execute("SELECT * FROM season")
        clothtypes = connect_execute("SELECT * FROM clothtypes")
        patterns = connect_execute("SELECT * FROM pattern")
        return [seasons, clothtypes, patterns]
    end

    def fetch_items(user_id)
        query = "SELECT wardrobe.*, season.season_name, clothtypes.type_name, pattern.pattern_name FROM wardrobe JOIN season ON wardrobe.season_id = season.season_id JOIN clothtypes ON wardrobe.type_id = clothtypes.type_id JOIN pattern ON wardrobe.pattern_id = pattern.pattern_id WHERE wardrobe.user_id = ?"
        connect_execute(query, user_id)
    end

    def register(username, password, password_confirm)
        result = connect_execute("SELECT * FROM users WHERE username = ?", username)

        if username.empty? || password.empty? || password_confirm.empty?
            flash[:message] = "You must fill out all the fields"
            redirect('/member')
        else
            if (password == password_confirm)
                if result.empty?
                    password_digest = BCrypt::Password.create(password)
                    connect_execute("INSERT INTO users (username, pwdigest) VALUES (?,?)",username,password_digest)

                    tagname = connect_execute("SELECT * FROM users WHERE username = ?", username).first
                    session[:username] = tagname["username"]
                    session[:id] = tagname["id"]
                    redirect('/profile')
                else
                    flash[:message] = "Username already exists"
                    redirect('/member')
                end
            else
                flash[:message] = "Passwords do not match"
                redirect('/member')
            end
        end
    end

    def login(username, password)
        result = connect_execute("SELECT * FROM users WHERE username = ?", username).first

        if result.nil?
            flash[:message] = "Username does not exist"
            redirect('/member')
        else
            pwdigest = result["pwdigest"]
            if BCrypt::Password.new(pwdigest) == password
                session[:id] = result["id"]
                session[:username] = result["username"]
                if username == "admin"
                    redirect('/admin')
                else
                    redirect('/profile')
                end
            else
                flash[:message] = "Wrong password!"
                redirect('/member')
            end
        end
    end

end
