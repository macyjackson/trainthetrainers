require 'sinatra'
require 'pg'
load './local_env.rb' if File.exist?('./local_env.rb')
enable :sessions

db_params = {
	host: ENV['dbhost'],
	port: ENV['port'],
	dbname: ENV['dbname'],
	user: ENV['dbuser'],
	password: ENV['password']
}

db = PG::Connection.new(db_params)

get '/' do
	user = session[:user] || ''
	erb :home, locals: {user: user}
end

post '/search' do
	title_isbn = params[:title_isbn]
	book = db.exec("SELECT title, isbn, id, quantity, price FROM book_table WHERE title='#{title_isbn}'")
	if book.count == 0
		book = db.exec("SELECT title, isbn, id, quantity, price FROM book_table WHERE isbn='#{title_isbn}'")
	end

	session[:book] = book[0]
	redirect '/results'
end

get '/results' do
	price = session[:book]['price'].to_s + ".00"
	erb :results, locals: {book: session[:book], price: price}
end

post '/login' do
	redirect '/login_page'
end

get '/login_page' do
	alert = params[:alert]
	erb :login
end

post '/user_login' do
	email = params[:email]
	password = params[:password]
	check_email = db.exec("SELECT * FROM user_table WHERE email = '#{email}'")
	if check_email.num_tuples.zero? == true
		alert = "This email does NOT exist"
		redirect '/login_page?alert=' + alert
	end

	db_password = check_email[0]['password']

	if password != db_password
		alert = 'This password does NOT match'
		redirect '/login_page?alert=' + alert
	else
		session[:user] = check_email[0]['email']
		redirect '/'
	end
end

post '/create' do
	redirect '/create_account'
end

get '/create_account' do
	message = params[:message]
	erb :create_account
end

post '/make_account' do
	users_name = params[:name]
	email = params[:email]
	password = params[:password]
	address = params[:address]
	city = params[:city]
	state = params[:state]
	zipcode = params[:zipcode]

	check_email = db.exec("SELECT * FROM user_table WHERE email = '#{email}'")
	if check_email.num_tuples.zero? == false
		message = "This email already exists"
		redirect '/create_account?message=' + message
	else
		db.exec("INSERT INTO user_table (name, address, city, state, zipcode, email, password) VALUES ('#{users_name}', '#{address}', '#{city}', '#{state}', '#{zipcode}', '#{email}', '#{password}')")

		session[:user] = email
		redirect '/'
	end
end

post '/cart' do
	quantity = params[:number_add_to_cart]
	user = db.exec("SELECT id FROM user_table WHERE email = '#{session[:user]}'")
	user_id = user[0]['id']
	book_id = session[:book]['id']


	db.exec("INSERT INTO cart (user_id, book_id, quantity) VALUES ('#{user_id}', '#{book_id}', '#{quantity}')")
	book_title = session[:book]['title']
	book = db.exec("SELECT * FROM book_table WHERE title='#{book_title}'")
	books_available = book[0]['quantity']
	new_total = books_available.to_i - quantity.to_i
	db.exec("UPDATE book_table SET quantity='#{new_total}' WHERE title = '#{book_title}'")

	redirect '/'
end

post '/view_cart' do
	user = db.exec("SELECT id FROM user_table WHERE email = '#{session[:user]}'")
	user_id = user[0]['id']
	db_order = db.exec("SELECT * FROM cart where user_id = '#{user_id}'")
	book_array = []
	total_ordered = []
	db_order.each do |order|
		book_id = order['book_id']
		book_info = db.exec("SELECT * FROM book_table where id = '#{book_id}'")
		book_array.push(book_info)
		total_ordered.push(order['quantity'])
	end


	erb :cart, locals: {book_array: book_array, total_ordered: total_ordered}
end
