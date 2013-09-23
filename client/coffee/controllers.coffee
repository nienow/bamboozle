@RoomListCtrl = ($scope) ->
  $scope.rooms = [{name: 'r1'}, {name: 'r2'}]

@RoomCtrl = ($scope, $routeParams) ->
  timerId = undefined
  timeLeft = undefined
  roomId = $routeParams.roomId

  $ ->
    socket = io.connect("http://localhost:8080")
    socket.on "game", setupGame
    socket.on "letters", onLetters
    socket.on 'time', updateTime
    socket.on 'results', writeResults
    socket.on 'restart', restartGame
    socket.on 'players', updatePlayers

    # TODO: disable settings for non-master
    #$('#settingsDiv input').prop('disabled', true)

    $('#publicField').on('click', 'input', ->
      socket.emit 'public', $(this).prop('checked')
    )

    $('.toggler').on('click', ->
      $(this).parent().find('.toggled').slideToggle()
    )

    $('#settingsDiv').on('click', '.button', ->
      values = {}
      settings = $('.setting').each ->
        name = $(this).attr('name')
        if (name)
          settingValue = $(this).find('input')[0].value
          values[name] = settingValue

      socket.emit 'settings', values
    )

    $('#startDiv').on('click', '.button', ->
      clearResults()
      socket.emit "ready"
    )

    $('#quitDiv').on('click', '.button', ->
      hide "quitDiv"
      socket.emit "voteRestart"
    )

    $('#wordInput').on('keypress', (e) ->
      if e and e.keyCode is 13
        word = $("#wordInput").val()

        socket.emit "word", word, (result) ->
          if result.success
            $("#wordList").append("<li>" + word + "</li>")
            $("#wordResult").html("word is valid")
          else
            $("#wordResult").html(result.error)

        $("#wordInput").val("")
    )

    console.log('the room: ' + roomId)

    socket.emit 'join',
      roomId: roomId
    , (data) ->
      if data.success
        show 'game'
      else
        console.log('could not register: ' + data.error)
        if data.error is 'roomDoesNotExist'
          #if confirm('Room does not exist. Do you want to create it?')
          socket.emit 'createRoom',
            roomId: roomId
          , (data) ->
            if data.success
              socket.emit 'join',
                roomId: roomId
              , (data) ->
                if data.success
                  show 'game'

    $("#startDiv").show()

  restartGame = (game) ->
    console.log('restarting game...')
    clearInterval timerId
    clearResults()
    setupGame(game)

  setupGame = (game) ->
    startTimer game.timeLeft, game.timeLimit
    hide "startDiv"
    if game.letters
      onLetters(game.letters)

  onLetters = (letters) ->
    populateBoard letters
    displayBoard()
    show "quitDiv"

  updatePlayers = (players) ->
    console.log('received player update: ' + JSON.stringify(players))

  populateBoard = (letters) ->
    table = "<table>"
    y = 0

    while y < letters.length
      table += "<tr>"
      x = 0

      while x < letters[y].length
        table += "<td>" + letters[y][x] + "</td>"
        x++
      table += "</tr>"
      y++
    table += "</table>"
    $('#board').html(table)

  displayBoard = ->
    show "mainDiv"
    show "wordInput"
    $("#wordInput").focus()

  clearResults = ->
    clear "board"
    clear "wordList"
    clear "wordResult"
    clear "results"
    clear "timer"

    hide "results"
    show "mainDiv"

  startTimer = (serverTimeLeft, timeLimit) ->
    timeLeft = serverTimeLeft
    #console.log(timeLeft + ', ' + timeLimit)
    show "timer"
    timerId = setInterval(->
      timeLeft = timeLeft - 1
      secondsLeft = timeLeft
      if secondsLeft > timeLimit
        secondsLeft = secondsLeft - timeLimit
      else $("#timer").toggleClass("timer-warn")  if secondsLeft < 15
      $("#timer").html(secondsLeft)
      timerExpired()  if secondsLeft is 0
    , 1000)

  timerExpired = ->
    hide "quitDiv"
    hide "wordInput"
    #hide "results"
    clearInterval @timerId
  #getResults()

  updateTime = (time) ->
    #console.log('time left: ' + time)
    timeLeft = time

  writeResults = (results) ->
    html = ""
    for userId,result of results
      playerWords = result.words
      #playerWords.sort()
      html += "<div class=\"playerResult\">"
      html += "<h1>" + userId + "</h1>"

      for word,scored of playerWords
        if scored
          html += "<li class=\"scored\">" + word + "</li>"
        else
          html += "<li class=\"unscored\">" + word + "</li>"
      html += "<div class=\"score\">" + result.score + "</div>"
      html += "</div>"
    $("#results").html(html)
    hide "mainDiv"
    show "results"
    show "startDiv"

  getParameterByName = (name) ->
    name = name.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]")
    regex = new RegExp("[\\?&]" + name + "=([^&#]*)")
    results = regex.exec(location.search)
    (if not results? then "" else decodeURIComponent(results[1].replace(/\+/g, " ")))