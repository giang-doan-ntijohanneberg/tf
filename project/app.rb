require 'slim'
require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'

get('/') do
    slim(:start)
end