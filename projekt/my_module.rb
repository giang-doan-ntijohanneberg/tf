require 'slim'
require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'


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
