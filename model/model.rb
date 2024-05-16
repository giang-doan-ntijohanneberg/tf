require 'slim'
require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'

module Model

    # Ensures that a user is logged in before accessing certain routes.
    # Redirects the user to '/' if they are not logged in and trying to access certain pages.
    # Redirects the user to '/' if they are not authorized to access admin pages.
    def require_login(session_id)
        if request.path_info != '/' && session_id.nil? && !['/member', '/profile/new', '/member/register', '/member/login', '/filter'].include?(request.path_info)
            redirect ('/')
        end
        if session_id != nil && session_id != 4 && ['/admin', '/admin/edit-user', '/admin/:id/show', '/admin/edit-data',].include?(request.path_info)
            flash[:message] = "This is not your place!!!"
            redirect('/')
        end
    end

    # Retrieves the owner ID of a specific garment stored in the wardrobe table.
    #Returns the ide of the owner of the specific garment, return nil if the garment does not exist.
    #
    #cloth_id [Interger] The ID of the garment whose owner ID is to be retrieved.
    #
    #@see Model#connect_execute
    #
    def get_owner_id(cloth_id)
        result = connect_execute("SELECT user_id FROM wardrobe WHERE cloth_id = ?", cloth_id)
        owner_id = result.first['user_id']
        if result.any?
            return owner_id
        end
    end
    
    # Connects to the SQLite database.
    # Returns SQLite database object.
    def connect_to_db(path)
        db = SQLite3::Database.new(path)
        db.results_as_hash = true
        return db
    end
    # Executes a SQL query on the database.
    # Returns results of the query as an array of hashes
    #
    #@see Model#connect_to_db
    #
    def connect_execute(query, *params)
        db = connect_to_db('db/projekt.db')
        db.execute(query, *params)
    end

    # Fetches data from the 'season', 'clothtypes', and 'pattern' tables.
    # Returns array containing data from the 'season', 'clothtypes', and 'pattern' tables.
    #
    #@see Model#connect_execute
    #
    def fetch_table()
        seasons = connect_execute("SELECT * FROM season")
        clothtypes = connect_execute("SELECT * FROM clothtypes")
        patterns = connect_execute("SELECT * FROM pattern")
        return [seasons, clothtypes, patterns]
    end

    # Fetches items from table 'wardrobe' for a specific user.
    # Returns wardrobe items for the specified user.
    #@see Model#connect_execute
    #
    def fetch_items(user_id)
        query = "SELECT wardrobe.*, clothtypes.type_name, pattern.pattern_name FROM wardrobe JOIN clothtypes ON wardrobe.type_id = clothtypes.type_id JOIN pattern ON wardrobe.pattern_id = pattern.pattern_id WHERE wardrobe.user_id = ?"
        connect_execute(query, user_id)
    end

    #Fetches data from table 'season_attribute' for a specific garment owned by a specific user
    #Return data from table 'season_attribute' for a specific garment owned by a specific user
    #
    #@see Model#connect_execute
    #
    def show_seasondata(user_id)
        cloth_id_row = connect_execute("SELECT cloth_id from wardrobe WHERE user_id=?", user_id)

        seasonat = []

        cloth_id_row.each do |cloth_id|
            seasonat << connect_execute("SELECT season_attribute.*, season.* FROM season_attribute JOIN season ON season_attribute.season_id = season.season_id WHERE season_attribute.cloth_id =?", cloth_id.first[1])
        end

        return seasonat
    end

    #Create a new garment to the user's wardrobe
    #
    #@see Model#connect_execute
    #
    def profile_add(season_id, season_id2, user_id, pattern_id, cloth_name, type_id, color_id, size, notes, image)
        connect_execute("INSERT INTO wardrobe (user_id, cloth_name, type_id, size, notes, image, pattern_id, color_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", user_id, cloth_name, type_id, size, notes, image, pattern_id, color_id)

        cloth_id_row = connect_execute("SELECT cloth_id FROM wardrobe WHERE user_id = ? AND cloth_name = ?", user_id, cloth_name).first
        cloth_id = cloth_id_row['cloth_id'] unless cloth_id_row.nil?

        connect_execute("INSERT INTO season_attribute (cloth_id, season_id, season_nbr) VALUES (?, ?, ?)", cloth_id, season_id, 1)
        connect_execute("INSERT INTO season_attribute (cloth_id, season_id, season_nbr) VALUES (?, ?, ?)", cloth_id, season_id2, 2)
    end



    # Deletes a garment from the user's wardrobe.
    #
    #@see Model#connect_execute
    #
    def item_delete(user_id, cloth_id)
        connect_execute("DELETE FROM wardrobe WHERE user_id=? AND cloth_id=?", user_id, cloth_id)
        connect_execute("DELETE FROM season_attribute WHERE cloth_id=?", cloth_id)
    end

    # Fetches a specific garment from the user's wardrobe.
    # Returns all data of the specified item.
    #
    #@see Model#connect_execute
    #
    def chosen_item(user_id, cloth_id)
        chosen_clothes = connect_execute("SELECT * FROM wardrobe WHERE user_id=? AND cloth_id=?", user_id, cloth_id).first
        return chosen_clothes
    end

    # Updates data of a specific garment in the user's wardrobe.
    #
    #@see Model#connect_execute
    #
    def item_update(season_id, season_id2, cloth_name, type_id, size, notes, pattern_id, color_id, user_id, cloth_id)

        if params[:image] && params[:image][:tempfile]
            image = params[:image][:tempfile].read
            connect_execute("UPDATE wardrobe SET cloth_name=?, type_id=?, size=?, notes=?, pattern_id=?, color_id=?, image=? WHERE user_id=? AND cloth_id=?", cloth_name, type_id, size, notes, pattern_id, color_id, image, user_id, cloth_id)
        else
            connect_execute("UPDATE wardrobe SET cloth_name=?, type_id=?, size=?, notes=?, pattern_id=?, color_id=? WHERE user_id=? AND cloth_id=?", cloth_name, type_id, size, notes, pattern_id, color_id, user_id, cloth_id)
        end

        cloth_id_row = connect_execute("SELECT cloth_id FROM wardrobe WHERE user_id = ? AND cloth_name = ?", user_id, cloth_name).first
        cloth_id = cloth_id_row['cloth_id'] unless cloth_id_row.nil?

        connect_execute("UPDATE season_attribute SET season_id=? WHERE cloth_id=? AND season_nbr=?", season_id, cloth_id, 1)
        connect_execute("UPDATE season_attribute SET season_id=? WHERE cloth_id=? AND season_nbr=?", season_id2, cloth_id, 2)

    end

    # Fetches wardrobe items for a specific user, filtered by season, pattern, type, color, and size.
    # user_id [Interger] ID of the user whose wardrobe items are to be fetched.
    # season_id [Interger] ID of the season to filter by.
    # pattern_id [Interger] ID of the pattern to filter by.
    # type_id [Interger] ID of the cloth type to filter by.
    # color_id [String] ID of the color to filter by.
    # size [String] Size to filter by.
    # Returns garments for the specified user and filters.
    #
    #@see Model#connect_to_db
    #
    def item_filter(user_id, season_id, pattern_id, type_id, color_id, size)
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

        if color_id && !color_id.empty? && color_id != "#000000"
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

        return items
    end

    # Fetches all garments along with their associated attributes (season, type, pattern).
    # Returns array containing all garments along with their associated attributes.
    #
    #@see Model#connect_execute
    #
    def admin_show_all_items()
        items = connect_execute("SELECT wardrobe.*, clothtypes.type_name, pattern.pattern_name FROM wardrobe JOIN clothtypes ON wardrobe.type_id = clothtypes.type_id JOIN pattern ON wardrobe.pattern_id = pattern.pattern_id")

        cloth_id_row = connect_execute("SELECT cloth_id from wardrobe")

        seasonat = []

        cloth_id_row.each do |cloth_id|
            seasonat << connect_execute("SELECT season_attribute.*, season.* FROM season_attribute JOIN season ON season_attribute.season_id = season.season_id WHERE season_attribute.cloth_id =?", cloth_id.first[1])
        end
        return [items, seasonat]
    end

    # Fetches all users from the database.
    # Returns array containing all users.
    #
    #@see Model#connect_execute
    #
    def select_all_users()
        users = connect_execute("SELECT * FROM users")
        return users
    end

    def admin_show_user_item(user_id)
        @username = connect_execute("SELECT username FROM users WHERE id = ?", user_id).first['username']

        items = connect_execute("SELECT wardrobe.*, clothtypes.type_name, pattern.pattern_name FROM wardrobe JOIN season ON wardrobe.season_id = season.season_id JOIN clothtypes ON wardrobe.type_id = clothtypes.type_id JOIN pattern ON wardrobe.pattern_id = pattern.pattern_id WHERE wardrobe.user_id = ?", user_id)

        cloth_id_row = connect_execute("SELECT cloth_id from wardrobe WHERE user_id=?", user_id)
        #cloth_id = cloth_id_row['cloth_id'] unless cloth_id_row.nil?

        seasonat = []

        cloth_id_row.each do |cloth_id|
            seasonat << connect_execute("SELECT season_attribute.*, season.* FROM season_attribute JOIN season ON season_attribute.season_id = season.season_id WHERE season_attribute.cloth_id =?", cloth_id.first[1])
        end

        return [@username, items, seasonat]
    end

    # Deletes a user along with their garments and associated attributes.
    #
    # user_id [Interger] ID of the chosen user.
    #
    #@see Model#connect_execute
    #
    def admin_delete_user(user_id)
        clothes = connect_execute("SELECT * FROM wardrobe WHERE user_id =?", user_id)
        p clothes
        connect_execute("DELETE FROM users WHERE id=?", user_id)
        connect_execute("DELETE FROM wardrobe WHERE user_id=?", user_id)
        clothes.each do |cloth|
            p cloth['cloth_id']
            connect_execute("DELETE FROM season_attribute WHERE cloth_id=?", cloth['cloth_id'])
        end
    end

    # Adds a new season, cloth type, or pattern to the database.
    #
    #@see Model#connect_execute
    #
    def admin_editdata(season, clothtype, pattern)
        if season && !season.empty?
            connect_execute("INSERT INTO season (season_name) VALUES(?)", season)
        end

        if clothtype && !clothtype.empty?
            connect_execute("INSERT INTO clothtypes (type_name) VALUES(?)", clothtype)
        end

        if pattern && !pattern.empty?
            connect_execute("INSERT INTO pattern (pattern_name) VALUES(?)", pattern)
        end
    end

    # Deletes a season, cloth type, or pattern from the database.
    #
    # season_id [Interger] ID of the season to be deleted.
    # pattern_id [Interger] ID of the pattern to be deleted.
    # type_id [Interger] ID of the cloth type to be deleted.
    #
    #@see Model#connect_execute
    #
    def admin_deletedata(season_id, clothtype_id, pattern_id)
        connect_execute("DELETE FROM season WHERE season_id=?", season_id)
        connect_execute("DELETE FROM season_attribute WHERE season_id=?", season_id)
        connect_execute("DELETE FROM clothtypes WHERE type_id=?", clothtype_id)
        connect_execute("DELETE FROM pattern WHERE pattern_id=?", pattern_id)
    end

    # Registers a new user.
    #If unsucessful registration redirect to '/member', if sucessful redirect to '/profile'
    #
    # username [String] name filled by user in the register form
    # password [String] password filled by user in the register form
    # password_confirm [String] password confirm filled by user in the register form
    #
    #@see Model#connect_execute
    #
    def register(username, password, password_confirm)
        result = connect_execute("SELECT * FROM users WHERE username = ?", username)

        if username.empty? || password.empty? || password_confirm.empty?
            flash[:message] = "You must fill out all the fields"
            redirect('/member')
            #return [nil, nil]
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
                    #[nil, nil]
                end
            else
                flash[:message] = "Passwords do not match"
                redirect('/member')
                #[nil, nil]
            end
        end
    end

    # Authenticates a user and logs user in, if username is admin redirect to '/admin', in unsucessful log in redirect to '/member' otherwise redirect to '/profile'
    #
    # username [String] name filled by user in the log in form
    # password [String] password filled by user in the log in form
    #
    def login(username, password)
        result = connect_execute("SELECT * FROM users WHERE username = ?", username).first
        if result.nil?
            flash[:message] = "Username does not exist"
            redirect('/member')
        else
            pwdigest = result["pwdigest"]
            if BCrypt::Password.new(pwdigest) == password
                [result["username"], result["id"], username == "admin" ? '/admin' : '/profile']
            else
                flash[:message] = "Wrong password!"
                redirect('/member')
            end
        end
    end
end
