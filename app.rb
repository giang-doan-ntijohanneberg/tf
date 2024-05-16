require 'slim'
require 'sinatra/flash'
require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'

require_relative 'model/model.rb'

enable :sessions

include Model

#Blocking a user's or guest's attempt to reach certain routes
#
before do
    session_id = session[:id]
    require_login(session_id)
end

#Display langding page
#
get('/') do
    slim(:index)
end

#Display landing page for registered user
#
# @see Model#fetch_table
# @see Model#fetch_items
# @see Model#show_seasondata
#
get('/profile') do
    user_id = session[:id].to_i

    seasons, clothtypes, patterns = fetch_table()

    items = fetch_items(user_id)

    seasonat = show_seasondata(user_id)

    if items.empty?
        return slim(:"wardrobe/index", locals:{patterns:patterns, seasons:seasons, clothtypes:clothtypes, items:items, seasonat:seasonat, message: "There is nothing in your wardrobe."})
    else
        slim(:"wardrobe/index", locals:{patterns:patterns, seasons:seasons, clothtypes:clothtypes, items:items, seasonat:seasonat})
    end
end

#Display form to create a new garment
#
# @see Model#fetch_table
#
get('/profile/new') do
    user_id = session[:id].to_i
    seasons, clothtypes, patterns = fetch_table()

    if user_id == 0
        flash[:message] = "Please log in to add clothes"
        redirect('/member')
    else
        slim(:"wardrobe/new", locals:{patterns:patterns, seasons:seasons, clothtypes:clothtypes})
    end
end

#Create a new garment, if all fields are filled redirect to '/profile', if not redirect to '/profile/new'
#
# @param [String] :cloth_name, Name of garment
# @param [String] :color_id, Id of garment
# @param [String] :size, Size of garment
# @param [String] :notes, Notes of garment
# @param [Integer] :season_id, Id of season 1
# @param [Integer] :season_id2, Id of season 2
# @param [Integer] :pattern_id, Id of pattern's type
# @param [Integer] :type_id, Id of garment's type
#
# @see Model#profile_add
#
post('/profile/new') do
    user_id = session[:id].to_i
    season_id = params[:season].to_i
    season_id2 = params[:season2].to_i
    pattern_id = params[:pattern].to_i
    cloth_name = params[:cloth_name]
    type_id = params[:clothtypes].to_i
    color_id = params[:color_picker]
    size = params[:size]
    notes = params[:notes]

    if params[:image] && params[:image][:tempfile]
        image = params[:image][:tempfile].read
    else
        flash[:message] = "Please upload an image"
        redirect('/profile/new')
    end

    if season_id == 0 || season_id2 == 0 || pattern_id == 0 || cloth_name.nil? || cloth_name.empty? || type_id == 0 || color_id.nil? || color_id.empty? || size.nil? || size.empty? || notes.nil? || notes.empty? || image.nil?
        flash[:message] = "Please fill out all the fields!"
        redirect('/profile/new')
    end

    profile_add(season_id, season_id2, user_id, pattern_id, cloth_name, type_id, color_id, size, notes, image)

    redirect('/profile')
end

#Delete an existing garment and redirect to '/profile'
#
#@param [Integer] :cloth_id, Id of chosen garment
#
#@see Model#item_delete
#@see Model#item_owner_id
#
post('/profile/:cloth_id/delete') do
    user_id = session[:id].to_i
    cloth_id = params[:cloth_id].to_i
    item_owner_id = get_owner_id(cloth_id)
    if user_id == item_owner_id
        item_delete(user_id, cloth_id)
        redirect('/profile')
    else
        flash[:message] = "You are not authorized to perform this action"
        redirect('/profile')
    end
end

#Display form to edit attributes of a garment
#
##@param [Integer] :cloth_id, Id of chosen garment
#
#@see Model#chosen_item
#@see Model#fetch_table
#
get('/profile/:cloth_id/edit') do
    user_id = session[:id].to_i
    cloth_id = params[:cloth_id].to_i
    chosen_clothes = chosen_item(user_id, cloth_id)

    seasons, clothtypes, patterns = fetch_table()

    slim(:"/wardrobe/edit", locals:{chosen_clothes:chosen_clothes, patterns:patterns, seasons:seasons, clothtypes:clothtypes})
end


#Update new attributes to a garment
#Regardless of image updating choice redirect to '/profile'
#
# @param [String] :cloth_name, Name of garment
# @param [String] :color_id, Id of garment
# @param [String] :size, Size of garment
# @param [String] :notes, Notes of garment
# @param [Integer] :season_id, Id of season 1
# @param [Integer] :season_id2, Id of season 2
# @param [Integer] :pattern_id, Id of pattern's type
# @param [Integer] :type_id, Id of garment's type
#
#@see Model#item_update
#
post('/profile/:cloth_id/update') do
    user_id = session[:id].to_i
    cloth_id = params[:cloth_id].to_i
    season_id = params[:season].to_i
    season_id2 = params[:season2].to_i
    pattern_id = params[:pattern].to_i
    cloth_name = params[:cloth_name]
    type_id = params[:clothtypes].to_i
    color_id = params[:color_picker]
    size = params[:size]
    notes = params[:notes]

    # if params[:image] && params[:image][:tempfile]
    #     image = params[:image][:tempfile].read
    #     item_update(season_id, season_id2, cloth_name, type_id, size, notes, image, pattern_id, color_id, user_id, cloth_id)
    #     redirect('/profile')
    # else
    #     item_update(season_id, season_id2, cloth_name, type_id, size, notes, image, pattern_id, color_id, user_id, cloth_id)
    #     redirect('/profile')
    # end
    item_owner_id = get_owner_id(cloth_id)
    if user_id == item_owner_id
        item_update(season_id, season_id2, cloth_name, type_id, size, notes, pattern_id, color_id, user_id, cloth_id)
        redirect('/profile')
    else
        flash[:message] = "You are not authorized to perform this action"
        redirect('/profile')
    end
    redirect('/profile')
end

#Display form to find a garment depending on chosen attributes, if guest redirect to '/member'
#
#@see Model#fetch_table
#
get('/filter') do
    user_id = session[:id].to_i

    seasons, clothtypes, patterns = fetch_table()

    if user_id == 0
        flash[:message] = "Please log in to find clothes"
        redirect('/member')
    else
        slim(:"wardrobe/filter", locals:{patterns:patterns, seasons:seasons, clothtypes:clothtypes})
    end
end

# Finding a garment depending on 5 attributes, if no garment matchs desired attributes redirect to '/filter'
#
# @param [String] :color_id, Id of garment
# @param [String] :size, Size of garment
# @param [Integer] :season_id, Id of season 1
# @param [Integer] :pattern_id, Id of pattern's type
# @param [Integer] :type_id, Id of garment's type
#
#@see Model#item_filter
#
post('/filter') do
    user_id = session[:id].to_i
    season_id = params[:season].to_i
    pattern_id = params[:pattern].to_i
    type_id = params[:clothtypes].to_i
    color_id = params[:color_picker]
    size = params[:size]

    items = item_filter(user_id, season_id, pattern_id, type_id, color_id, size)

    if items.empty?
        flash[:message] = "There are no such clothes in your wardrobe"
        redirect('/filter')
    else
        slim(:"wardrobe/filter_result", locals:{items:items})
    end
end

#Display register form and log in form
#
get('/member') do
    slim(:new)
end

# Attempt register and update the session
# Redirects to '/profile' if successful login
#
# @param [String] :username, The username
# @param [String] :password, The password
# @param [String] :password_confirm, The repeated password
#
# @see Model#register
#
post('/member/register') do
    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]

    session[:username], session[:id] = register(username, password, password_confirm)
    redirect('/profile') if session[:username] && session[:id]
end

#Attempt login and update the session
#
#@see Model#login
#
post('/member/login') do
    username = params[:username]
    password = params[:password]
    session[:username], session[:id], redirect_path = login(username, password)
    #session[:attempts], session[:last_time] = update_attempts(attempts, last_time)
    redirect(redirect_path) if session[:username] && session[:id] && redirect_path
end

# helpers do
#     def reset_login_attempts
#         session.delete(:attempts)
#         session.delete(:last_time)
#     end
# end

#Clears all sessions and logs the user out
#
get('/logout') do
    session.clear
    flash[:notice] = "You have been logged out"
    redirect('/')
end

# Display all existing garments of all users
#
# @see Model#fetch_table
# @see Model#admin_show_all_items
#
get('/admin') do
    seasons, clothtypes, patterns = fetch_table()

    items, seasonat = admin_show_all_items()

    if items.empty?
        slim(:"admin/index", locals:{patterns:patterns, seasons:seasons, clothtypes:clothtypes, items:items, seasonat:seasonat, message: "Nothing is added"})
    else
        slim(:"admin/index", locals:{patterns:patterns, seasons:seasons, clothtypes:clothtypes, items:items, seasonat:seasonat})
    end

end

#Display all users
#
# @see Model#select_all_users()
#
get('/admin/edit-user') do
    users = select_all_users()
    slim(:"admin/user-edit/edit", locals: {users: users})
end

#Display all garments of a chosen user, if user has no garment redirect to '/admin/edit-user'
#
# @param [String] :user_id, Id of chosen user
#
# @see Model#connect_execute
# @see Model#fetch_table
# @see Model#admin_show_user_item
#
get('/admin/:id/show') do
    user_id = params[:id].to_i

    users = connect_execute("SELECT * FROM users")

    seasons, clothtypes, patterns = fetch_table()

    @username, items, seasonat = admin_show_user_item(user_id)

    if items.empty?
        flash[:message] = "This user has not added anything"
        redirect('/admin/edit-user')

    else
        slim(:"admin/show", locals:{patterns:patterns, seasons:seasons, clothtypes:clothtypes, users:users, items:items, seasonat:seasonat})
    end
end

#Delete an existing user and redirect to '/admin/edit-user'
#
# @param [String] :user_id, Id of chosen user
#
# @see Model#admin_delete_user
#
post('/admin/:id/delete') do
    user_id = params[:id].to_i
    admin_delete_user(user_id)
    redirect('/admin/edit-user')
end

#Display 3 forms to delete och create new data for attributes: seasons, clothtypes, patterns
#
# @see Model#fetch_table
#
get('/admin/edit-data') do
    seasons, clothtypes, patterns = fetch_table()

    slim(:"admin/edit", locals: {seasons:seasons, clothtypes:clothtypes, patterns:patterns})
end

#Create new data for attributes seasons, clothtypes and patterns and redirect to '/admin/edit-data'
#
# @param [String] :season, Name of season
# @param [String] :clothtype, Name of clothtype
# @param [String] :pattern, Name of pattern
#
# @see Model#admin_editdata
#
post('/admin/edit-data') do
    season = params[:season_name]
    clothtype = params[:type_name]
    pattern = params[:pattern_name]

    admin_editdata(season, clothtype, pattern)

    redirect('/admin/edit-data')
end

#Delete an existing data from attributes season, pattern, clothtype and redirect to '/admin/edit-data'
#
# @param [String] :season, Name of season
# @param [String] :clothtype, Name of clothtype
# @param [String] :pattern, Name of pattern
#
# @see Model#admin_deletedata
#
post('/admin/:id/deletedata') do
    season_id = params[:season_id].to_i
    clothtype_id = params[:type_id].to_i
    pattern_id = params[:pattern_id].to_i
    admin_deletedata(season_id,clothtype_id, pattern_id)
    redirect('/admin/edit-data')
end
