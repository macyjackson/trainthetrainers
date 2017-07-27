require 'sinatra'
require 'pg'
require 'date'
require 'mail'
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

Mail.defaults do
	delivery_method :smtp,
	address: "email-smtp.us-east-1.amazonaws.com",
	port: 587,
	:user_name => ENV['a3smtpuser'],
	:password => ENV['a3smtppass'],
	:enable_ssl => true
end


get '/' do
	user = session[:user] || ''
	erb :home, locals: {user: user}
end

post '/search' do
	title_isbn = params[:title_isbn] #search for title or isbn
	book = db.exec("SELECT title, isbn, id, quantity, money FROM book_table WHERE title='#{title_isbn}'") #setting the variable and searching the database for anything that comes back with a title. Select is carrying all the data from the table (because all are specified). Can use astric to select all but could take more time for program to run.
	if book.count == 0
		book = db.exec("SELECT title, isbn, id, quantity, money FROM book_table WHERE isbn='#{title_isbn}'")
	end

	session[:book] = book[0] #if we to have a book that returns, session book will return with all the info.
	redirect '/results' # redirecting to results route
end

get '/results' do
	money = session[:book]['money']
	erb :results, locals: {book: session[:book], price: money} #Can use replace feature in find menu to replace all instances of a word (ie, price to money) but will need to change in results.erb file also.
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
# check_email is the variable we use to set our restult back from the database to make sure our email exists.
	check_email = db.exec("SELECT * FROM user_table WHERE email = '#{email}'")
	if check_email.num_tuples.zero? == true #num_tuples.zero? will check to make sure the array that comes back contains something
			alert = "This email does NOT exist"
		redirect '/login_page?alert=' + alert
	end

	db_password = check_email[0]['password'] #first index [0] is a hash

	if password != db_password
		alert = 'This password does NOT match'
		redirect '/login_page?alert=' + alert #will redirect them back to the login
	else
		session[:user] = check_email[0]['email']
		redirect '/' #redirects back to the homepage. Forwardslash is the homepage in Sinatra.
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
	users_name = params[:name] #all used to create an account. This is where our params come in.
	email = params[:email]
	password = params[:password]
	address = params[:address]
	city = params[:city]
	state = params[:state]
	zipcode = params[:zipcode]

	check_email = db.exec("SELECT * FROM user_table WHERE email = '#{email}'") #using a variable to call to see if the email the user inputted is in the database. Google sequel statements. Use scripts in pgAdmin. Use query tool in pgAdmin. Can test in pgAdmin. * means all. Check out reverence in W3 schools.
	if check_email.num_tuples.zero? == false #if false, redirect back to create account view to say email already exists.
		message = "This email already exists"
		redirect '/create_account?message=' + message
	else
		db.exec("INSERT INTO user_table (name, address, city, state, zipcode, email, password) VALUES ('#{users_name}', '#{address}', '#{city}', '#{state}', '#{zipcode}', '#{email}', '#{password}')") #else user will enter information and create account.

		session[:user] = email
		redirect '/'
	end
end

post '/cart' do
	quantity = params[:number_add_to_cart]
	user = db.exec("SELECT id FROM user_table WHERE email = '#{session[:user]}'") #getting data on user. Using a specific column instead of all the data in the table.
	user_id = user[0]['id'] #selecting hash from the array and then selecting the id from the hash
	book_id = session[:book]['id'] #selecting specific data from the hash, pulling out id


	db.exec("INSERT INTO cart (user_id, book_id, quantity) VALUES ('#{user_id}', '#{book_id}', '#{quantity}')") #need to be in the correct order.  Insert starts a new row.
	book_title = session[:book]['title'] #selecting a book title from our hash we have set as a session.
	book = db.exec("SELECT * FROM book_table WHERE title='#{book_title}'") #setting the variable book and setting the book_table database for that book title.
	books_available = book[0]['quantity'] #book is array and zero is the index. Setting book to all the rows. Need to know the quantitiy from the hash. 
	new_total = books_available.to_i - quantity.to_i #deducting quantity
	db.exec("UPDATE book_table SET quantity='#{new_total}' WHERE title = '#{book_title}'") #using update statement, Resetting the database to the new quantity.

	redirect '/' #back to home to search another book or view cart
end

post '/view_cart' do
	user = db.exec("SELECT id FROM user_table WHERE email = '#{session[:user]}'") #selecting the id from the user bc id is what we reference the user with in the database.
	user_id = user[0]['id'] #setting the id to a variable
	db_order = db.exec("SELECT * FROM cart where user_id = '#{user_id}'") #on this select statement we are trihng to select all orders in cart.
	book_array = [] #118-125 creating two arrays to store our book info.
	total_ordered = [] #storing amount ordered
	db_order.each do |order| #if we have one order or multiple orders it will iterate through (pg result) all orders. Cannot set pg to a session- will get error: no dump data. 
		book_id = order['book_id'] #grabbing book id of that order and setting it to the variable book_id.
		book_info = db.exec("SELECT * FROM book_table where id = '#{book_id}'") #selecting all the book info with the book id we set with the infor (id, quantity, etc.) from prior line.
		book_array.push(book_info[0]) # pushing book info into an array. Can make array as big as needed.
		total_ordered.push(order['quantity']) #push it into total_ordered array
	end
	 total_ordered.each do |total|
	 	print total + "TOTAL HERE"
	 end

	 session[:book_array] = book_array
	 session[:total_ordered] = total_ordered


	erb :cart, locals: {book_array: book_array, total_ordered: total_ordered} 
	end #passed in as locals (variables we can pass from the back end to the front end so we can view that info) and put in our cart. (Params is how we get info from the front end to the back end.)
		#app.rb is your back end. views and those files are front (what ppl see). Communication between app & database happens within app.rb. Information we get from user comes from front end/views.

post '/confirm_order' do #posting to confirm order, goes here when you click confirm order button
	user_info = db.exec("SELECT * FROM user_table WHERE email = '#{session[:user]}'") #selecting all (*) the user's info to use later for the email. When user logs in the info will be stored.
	user_id = user_info[0]['id'] #selecting the id out of the array and hash so we csn assign it to our tables so we can reference it to who made the purchases.

	index = 0 #self contained counter so we can keep session book array an d
	session[:book_array].each do |book| #can iterate over that array useing .each_do
		book_id = book['id']
		date = Time.now.strftime("%m/%d/%Y %H:%M")
		db.exec("INSERT INTO confirmed_orders (user_id, book_id, quantity, date) VALUES ('#{user_id}', '#{book_id}', '#{session[:total_ordered][index]}', '#{date}')") #set quantity to session[:total_ordered], a multidimensional array. Setting the word index (or name) will light up different colors. Colors can help you read your code and can indicate errors. Index is used to set an array position (a counter).
		index = index + 1
		db.exec("DELETE FROM cart WHERE user_id = '#{user_id}'") #deletes the items from your cart after order is confirmed. See line 158- all info was inserted into confirmed orders before deleting.
	end
	email = user_info[0]['email'] #emails them all the info

	email_body = erb(:email_confirmation, locals: {book_array: session[:book_array], total_ordered: session[:total_ordered], user_info: user_info}) #setting an email body from info on line 164. This is where you get all params that need to go in your email.
	mail = Mail.new do #using mail gem, creating a new instance of an email. That mail is a new object.
		from     ENV['from'] #go to local ENV this is where it is coming from. ENV is a hidden file with confidential info. the .gitignore when we do git add when we have gitignore it will see which file names ENV is in them and will not push them. Using bcript, ENV and gitignore is a must!
		to 			 email #set variable email to user's email (that variable is set up above). From and to commands come from mail gem.
		subject  "Thank you for your purchase." #universal subject for whatever you want to tell your user.

		html_part do #setting up the body. content is html & text
			content_type 'text/html'
			body          email_body #body is going to be variable body set above. Can add css to make it look better. Email body used to erb
		end
	end

	mail.deliver! #telling mail gem there is a .deliver telling it to deliver the email. like a function but is an API, shorthanded function which is part of a library. The .deliver is part of the gem. The .deliver is something you can do from the gem. 

	redirect '/' #redirect to home
end