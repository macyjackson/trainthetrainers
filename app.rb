require 'sinatra'

get '/' do
	erb :home
end

post '/search' do
	title = params[:title]
	
end