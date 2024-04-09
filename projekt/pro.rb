require 'slim'
require 'sinatra/flash'
require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'

require_relative './model.rb'

enable :sessions

before do
    if request.path_info != '/' &&
        session[:id] == nil &&
        request.path_info != '/member' &&
        request.path_info != '/add' &&
        request.path_info != '/newmember' &&
        request.path_info != '/login' &&
        request.path_info != '/filter'
        redirect ('/')
    end
end


get('/') do
    slim(:index)
end



get('/profile') do
    user_id = session[:id].to_i
    db = connect_to_db('db/projekt.db')
    seasons = db.execute("SELECT * FROM season")
    clothtypes = db.execute("SELECT * FROM clothtypes")
    patterns = db.execute("SELECT * FROM pattern")

    items = db.execute("SELECT wardrobe.*, season.season_name, clothtypes.type_name, pattern.pattern_name FROM wardrobe JOIN season ON wardrobe.season_id = season.season_id JOIN clothtypes ON wardrobe.type_id = clothtypes.type_id JOIN pattern ON wardrobe.pattern_id = pattern.pattern_id WHERE wardrobe.user_id = ?", user_id)

    if items.empty?
        return slim(:"wardrobe/profile", locals:{patterns:patterns, seasons:seasons, clothtypes:clothtypes, items:items, message: "There is nothing in your wardrobe."})
    else
        slim(:"wardrobe/profile", locals:{patterns:patterns, seasons:seasons, clothtypes:clothtypes, items:items})
    end
end

get('/add') do
    user_id = session[:id].to_i
    db = connect_to_db('db/projekt.db')
    seasons = db.execute("SELECT * FROM season")
    clothtypes = db.execute("SELECT * FROM clothtypes")
    patterns = db.execute("SELECT * FROM pattern")

    if user_id == 0
        flash[:message] = "Please log in to add clothes"
        redirect('/member')
    else
        slim(:"wardrobe/add", locals:{patterns:patterns, seasons:seasons, clothtypes:clothtypes})
    end
end


post('/addclothes') do
    user_id = session[:id].to_i
    season_id = params[:season].to_i
    pattern_id = params[:pattern].to_i
    cloth_name = params[:cloth_name]
    type_id = params[:clothtypes].to_i
    color_id = params[:color_picker]
    size = params[:size]
    notes = params[:notes]
    image = params[:image][:tempfile].read

    db = connect_to_db('db/projekt.db')
    db.execute("INSERT INTO wardrobe (user_id, season_id, cloth_name, type_id, size, notes, image, pattern_id, color_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", user_id, season_id, cloth_name, type_id, size, notes, image, pattern_id, color_id)
    redirect('/profile')
end

post('/profile/:cloth_id/delete') do
    user_id = session[:id].to_i
    cloth_id = params[:cloth_id].to_i
    db = connect_to_db('db/projekt.db')
    db.execute("DELETE FROM wardrobe WHERE user_id=? AND cloth_id=?", user_id, cloth_id)
    redirect('/profile')
end

get('/profile/:cloth_id/edit') do
    user_id = session[:id].to_i
    cloth_id = params[:cloth_id].to_i
    db = connect_to_db('db/projekt.db')
    chosen_clothes = db.execute("SELECT * FROM wardrobe WHERE user_id=? AND cloth_id=?", user_id, cloth_id).first
    seasons = db.execute("SELECT * FROM season")
    clothtypes = db.execute("SELECT * FROM clothtypes")
    patterns = db.execute("SELECT * FROM pattern")
    p "Edit this piece #{chosen_clothes}"
    slim(:"/wardrobe/edit", locals:{chosen_clothes:chosen_clothes, patterns:patterns, seasons:seasons, clothtypes:clothtypes})
end

post('/profile/:cloth_id/update') do
    user_id = session[:id].to_i
    cloth_id = params[:cloth_id].to_i
    season_id = params[:season].to_i
    pattern_id = params[:pattern].to_i
    cloth_name = params[:cloth_name]
    type_id = params[:clothtypes].to_i
    color_id = params[:color_picker]
    size = params[:size]
    notes = params[:notes]
    image = params[:image][:tempfile].read
    db = connect_to_db('db/projekt.db')
    db.execute("UPDATE wardrobe SET season_id=?, cloth_name=?, type_id=?, size=?, notes=?, image=?, pattern_id=?, color_id=? WHERE user_id=? AND cloth_id=?", season_id, cloth_name, type_id, size, notes, image, pattern_id, color_id, user_id, cloth_id)
    redirect('/profile')
end

get('/filter') do
    user_id = session[:id].to_i
    db = connect_to_db('db/projekt.db')
    seasons = db.execute("SELECT * FROM season")
    clothtypes = db.execute("SELECT * FROM clothtypes")
    patterns = db.execute("SELECT * FROM pattern")

    if user_id == 0
        flash[:message] = "Please log in to find clothes"
        redirect('/member')
    else
        slim(:"wardrobe/filter", locals:{patterns:patterns, seasons:seasons, clothtypes:clothtypes})
    end
end

post('/filter') do
    user_id = session[:id].to_i
    season_id = params[:season].to_i
    pattern_id = params[:pattern].to_i
    type_id = params[:clothtypes].to_i
    color_id = params[:color_picker]
    size = params[:size]
    db = connect_to_db('db/projekt.db')

    query = "SELECT wardrobe.*, season.season_name, clothtypes.type_name, pattern.pattern_name FROM wardrobe JOIN season ON wardrobe.season_id = season.season_id JOIN clothtypes ON wardrobe.type_id = clothtypes.type_id JOIN pattern ON wardrobe.pattern_id = pattern.pattern_id WHERE wardrobe.user_id = ?"

    conditions = []
    filter_params = [user_id]

    if season_id > 0
        conditions << "wardrobe.season_id = ?"
        filter_params << season_id
    end

    if type_id > 0
        conditions << "wardrobe.type_id = ?"
        filter_params << type_id
    end

    if pattern_id > 0
        conditions << "wardrobe.pattern_id =?"
        filter_params << pattern_id
    end


    if color_id && !color_id.empty?
        conditions << "wardrobe.color_id =?"
        filter_params << color_id
    end

    if size && !size.empty?
        conditions << "wardrobe.size = ?"
        filter_params << size
    end

    if conditions.any?
        query += " AND " + conditions.join(" AND ")
    end

    items = db.execute(query, *filter_params)

    if items.empty?
        flash[:message] = "There are no such clothes in your wardrobe"
        redirect('/filter')
    else
        slim(:"wardrobe/filter_result", locals:{items:items})
    end

end

get('/member') do
    slim(:member)
end

post('/newmember') do
    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]

    db = connect_to_db('db/projekt.db')
    result = db.execute("SELECT * FROM users WHERE username = ?", username)

    if (password == password_confirm)
        if result.empty?
            password_digest = BCrypt::Password.create(password)
            db.execute("INSERT INTO users (username, pwdigest) VALUES (?,?)",username,password_digest)
            tagname = db.execute("SELECT * FROM users WHERE username = ?", username).first
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

post('/login') do
    username = params[:username]
    password = params[:password]
    db = connect_to_db('db/projekt.db')
    result = db.execute("SELECT * FROM users WHERE username = ?", username).first
    if result.nil?
        "Username does not exist"
    else
        pwdigest = result["pwdigest"]
        if BCrypt::Password.new(pwdigest) == password
            session[:id] = result["id"]
            session[:username] = result["username"]
            redirect('/profile')
        else
            "Wrong password"
        end
    end
end

get('/logout') do
    session.clear
    flash[:notice] = "You have been logged out"
    redirect('/')
end
