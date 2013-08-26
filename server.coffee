express = require 'express'
app = express()
game = require './routes/game'
rest = require('./routes/simple-rest').init(app)
http = require('http').createServer(app)
io = require('socket.io').listen(http)
path = require 'path'
coffee = require 'coffee-middleware'
fs = require 'fs'
less = require 'less-middleware'

ipaddr  = process.env.OPENSHIFT_NODEJS_IP || process.env.IP || "127.0.0.1"
port    = process.env.OPENSHIFT_NODEJS_PORT || process.env.PORT || 8080

http.listen(port, ipaddr)

coffeeDir = path.join(__dirname, 'coffee')
jsDir = path.join(__dirname, 'public/javascripts')

app.use(less(
  src: path.join(__dirname, 'public/stylesheets')
  prefix: '/stylesheets'
))

app.use(coffee(
  src: path.join(__dirname, 'public/javascripts')
  prefix: '/javascripts'
))

app.use(express.static(path.join(__dirname, 'public')))
app.set('views', __dirname + '/views')
app.set('view engine', 'jade')

rest.get '/letters', (query) ->
  game.getLetters(query.hangoutId)

rest.get '/games', (query) ->
  game.getGames()

rest.get '/words', (query) ->
  game.getWords(query.hangoutId, query.userId)

rest.get '/time', (query) ->
  game.getTimeRemaining(query.hangoutId)

rest.get '/results', (query) ->
  game.getResults(query.hangoutId)

rest.get '/game', (query) ->
  game.getGame(query.hangoutId)

app.get '/', (req, res) ->
  res.render(__dirname+'/view/index.jade')

app.get '/h', (req, res) ->
  res.render(__dirname+'/view/hindex.jade')

io.sockets.on 'connection', (socket) ->
  socket.on 'register', (o) ->
    socket.username = o.userId
    socket.room = o.hangoutId
    socket.join o.hangoutId
    result = game.register(o.hangoutId, o.userId)
    if (result)
      socket.emit('game', result)

  socket.on 'ready', ->
    result = game.ready(socket.room, socket.username)
    if (result)
      io.sockets.in(socket.room).emit('game', result)

  socket.on('newGame', game.newGame)
  socket.on('word', game.submitWord)
  socket.on('quit', game.quit)

  #socket.on('ping', game.ping)