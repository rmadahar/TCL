$(document).ready(function () {

    var debugStr;
    var PERSONAL_USER_ID = ##TP_USER_ID##;
    var GAME_ID = ##TP_GAME_ID##;
	$('#game_id').find('span').text(GAME_ID);
    var turn_no=-1;
    var deck = ["Aces", "Twos", "Threes", "Fours", "Fives", "Sixes", "Sevens", "Eights", "Nines", "Tens", "Jacks", "Queens", "Kings"]; 
    var cards;
    var kind=-1;
    var new_round=1;
    var turn=0;
	var count=0;
    var numberOfCards = 52;
    //---------------------------------
    var cardWidth = 79;
    var cardHeight = 123;
    var backOverlap = 5;
    var defaultOverlap = 20;
    //---------------------------------
    var numPlayers = 4;

    // Variables to hold players and cards
	var personalPlayerName;
    var players = [];
	var currentPlayer;
    var playerOneCards = [];
    var playerTwoCardCount = 0;
    var playerThreeCardCount = 0;
    var playerFourCardCount = 0;
    var tableCardCount = 0;
    var discardedCardKinds = [];
    var selectedCardIndexes = [];
    var selectedCardNumbers = [];

    // Get the canvas and context
    var canvas = document.getElementById("GameBoard");
    var context = canvas.getContext("2d");

    // Default values for variables
    var overlap = defaultOverlap;
    var cardDisplayWidth = 0;
    
	var counter;

	function timer() {
		if (count == 30) {
			$('#timer').css('color', 'black');
		}
		count -= 1;
		if (count == 0) {
			resetTimer();
			alert("Time's Up!");
			var log_message = personalPlayerName+" ran out of time!";
			//TODO: call timeout action
			$.ajax({
            	url: "##TP_CGI_URL##?action=CHEAT_timeout_action&user_id="+PERSONAL_USER_ID+"&game_id="+GAME_ID+"&log_message="+log_message,
                cache: false 
            })
          	.done(function(results) {
            	var jsonResp = JSON.parse(results);
				turn_no=jsonResp.turn_no;
				new_round=jsonResp.new_round;
                drawGameBoard(jsonResp);
				if (new_round) {
					kind = -1;
				} else {
					kind=jsonResp["kind"];
				}
				var log_message=jsonResp.log_message;
				updateMessage(log_message);
                turn=0;  
				displayKind();
            });
            return;
		}
		if (count == 5) {
			$('#timer').css('color', 'red');
		}
		$('#timer').find('span').text(count);
	}

	function resetTimer() {
		clearInterval(counter);
		count = 30;
		$('#timer').css('color', 'white');
		$('#timer').find('span').text(count);
	}
	
	resetTimer();
    
    // ----------------------------------------------------- AJAX REQUESTS -------------------------------------------------------------------
    $("#play_btn").click(function() {
            if(turn==0) return;
            if (new_round==1 && kind==-1) {alert("Choose a kind");return;}
            cards=getSelectedCards();
			if (cards.length==0) {alert("Choose 1-3 cards to play"); return;}
            console.debug(cards);
			var log_message = personalPlayerName+" played "+cards.length+" "+deck[kind]+".";
			resetTimer();
            $.ajax({
                    url: "##TP_CGI_URL##?action=CHEAT_play_action&user_id="+PERSONAL_USER_ID+"&game_id="+GAME_ID+"&kind="+kind+"&cards="+cards+"&log_message="+log_message,                    
                    cache: false
                    })
                    .done( function(results) {
                                        var jsonResp = JSON.parse(results);
                                        turn=0;
   	                                    turn_no=jsonResp["turn_no"];
                                        new_round=jsonResp["new_round"];
										if (new_round) {
											kind = -1;
										} else {
											kind=jsonResp["kind"];
										}
										var log_message = jsonResp.log_message;
										updateMessage(log_message);
										displayKind();
                                        drawGameBoard(jsonResp);
 										var winner_id = jsonResp.winner_id;
										if (winner_id > -1) {
											win_game(winner_id);
										}
                                    });        
                    });

    $("#cheat_btn").click(function() {
            if(turn==0 || tableCardCount==0) return;
			var log_message = personalPlayerName+" called cheat!";
			resetTimer();
            $.ajax({
                    url: "##TP_CGI_URL##?action=CHEAT_cheat_action&user_id="+PERSONAL_USER_ID+"&game_id="+GAME_ID+"&log_message="+log_message,
                    cache: false 
                    })
                    .done( function(results) {
                                        var jsonResp = JSON.parse(results);
                                        turn_no=jsonResp["turn_no"];
										new_round=jsonResp["new_round"];
                                        drawGameBoard(jsonResp);
										var winner_id = jsonResp.winner_id;
										if (winner_id > -1) {
											win_game(winner_id);
										}
										if (new_round) {
											kind = -1;
										} else {
											kind=jsonResp["kind"];
										}
										var log_message=jsonResp.log_message;
										updateMessage(log_message);
										if (jsonResp.cur_player_id == PERSONAL_USER_ID) {
											turn=1;
											setUpSelect();
											resetTimer();
											counter = setInterval(timer, 1000);
										} else {
                                        	turn=0;  
											displayKind();
										}
                                       });
        });

    setTimeout(function CheckTurn() {
                              $.ajax({
                                      url: "##TP_CGI_URL##?action=CHEAT_check_status&user_id="+PERSONAL_USER_ID+"&game_id="+GAME_ID+"&turn_no="+turn_no,
                                      cache: false 
                                    }).done( function(results) {
                                                                var jsonResp = JSON.parse(results);
																var new_turn = jsonResp["turn_no"];
																if (new_turn != turn_no) {
                                                                	turn_no=new_turn;
																    new_round=jsonResp["new_round"];
																	var log_message=jsonResp.log_message;
																	updateMessage(log_message);
                                                                	debugStr="jsonResp:"+jsonResp+" turn:"+turn_no;
                                                                	console.debug(debugStr);
																	drawGameBoard(jsonResp);
                                                                	var winner_id = jsonResp.winner_id;
																	if (winner_id > -1) {
																		win_game(winner_id);
																	}
																	if ( jsonResp["cur_player_id"]==PERSONAL_USER_ID) {
                                                                      	turn=1;
																		// check if it's first round so u can choose the kind
																	  	if (new_round) {
																			kind = -1;
																	  		setUpSelect();
																  		} else {
																			kind=jsonResp["kind"];
																	 	 	displayKind();
																		}
																		resetTimer();
																		counter = setInterval(timer, 1000);
                                                                    }
                                                    	            else { 
                                                                      turn=0;
																	  if (new_round) {
																		  kind = -1;
																	  } else {
																		  kind=jsonResp["kind"];
																	  }
																	  displayKind();
                                                                     }
																}
                                                              });                   
                                      setTimeout( CheckTurn , 5000); // reset to 4000
                                  }, 1 );


    // ----------------------------------------------------- AJAX REQUESTS -------------------------------------------------------------------

	var win_game = function(winner_id) {
		for(var i = 0; i < players.length; i++) {
			if (players[i].user_id == winner_id) {
				alert(players[i].name+" has won!");
				break;
			}
		}
		window.location.replace("##TP_CGI_URL##?action=CHEAT_disp_rooms&user_id="+PERSONAL_USER_ID);
	}
	
	var cleanUpDashboard = function() {
		var dropdown = $('#dropdown');
		if (dropdown.length) {
			dropdown.off('change');
			dropdown.remove();
		}
		$('#kindinfo').remove();
	};

	var setUpSelect = function() {
		cleanUpDashboard();
		console.log(deck);
		var selectPara = $('<p></p>').insertAfter('#timer');
		var select = $('<select id="dropdown"></select>').appendTo(selectPara);
		var option = '<option value="-1">Please select a kind</option>';
		$(select).append(option);
		$.each( deck, function(index, value) {
										  if (discardedCardKinds.indexOf(index) === -1) { 
	                                          option='<option value="'+index+'">'+value+'</option>';  
    	                                      $(select).append(option);
										  }
                                         });


		$("#dropdown").change(function() {
                                      kind = $(this).val();
                                      debugStr="kind:"+deck[kind]+" "+kind; 
                                      console.debug(debugStr);
                                      });
    };

	var displayKind = function() {
		cleanUpDashboard();
		var kindToDisplay;
		if (kind == -1) {
			kindToDisplay = "has not been chosen";
		} else {
			kindToDisplay ="is "+deck[kind];
		}
		$('#timer').after('<p id="kindinfo">The current kind '+kindToDisplay+'.</p>');
	};

	var updateMessage = function(message) {
		$('#turn_no').find('span').text(turn_no);
		$('#log_message').text(message);
	};
     
    // Draws the game board on each turn
    function drawGameBoard(jsonData) {

      // Set up some default/starting values for variables
      overlap = defaultOverlap;
      var cards = [];

      // Retrieve the player info
      var playerOneIndex = 0;
        var jsonPlayers = jsonData.players;
        for (var i = 0; i < jsonPlayers.length; i++) {
          if (jsonPlayers[i].user_id == PERSONAL_USER_ID) {
            playerOneIndex = i;
			personalPlayerName = jsonPlayers[i].name;
            break;
          }
        }
        for (var i = playerOneIndex; i < numPlayers; i++) {
          players.push(jsonPlayers[i]);
        }
        for (i = 0; i < playerOneIndex; i++) {
          players.push(jsonPlayers[i]);
        }

      var cards = jsonData.cards;

	currentPlayer = jsonData.cur_player_id;

      // Empty the card info variables and repopulate them
      playerOneCards = [];
      playerTwoCardCount = 0;
      playerThreeCardCount = 0;
      playerFourCardCount = 0;
      tableCardCount = 0;
      discardedCardKinds = [];
  	  if (!turn) {
		  selectedCardIndexes = [];
		  selectedCardNumbers = [];
	  }

      for (i = 0; i < cards.length; i++) {
        switch(cards[i]) {
          case players[0].user_id:
            playerOneCards.push(i);
            break;
          case players[1].user_id:
            playerTwoCardCount++;
            break;
          case players[2].user_id:
            playerThreeCardCount++;
            break;
          case players[3].user_id:
            playerFourCardCount++;
            break;
          case 0:
            tableCardCount++;
            break;
          case -1:
            var kind = i % 13;
            var isDiscarded = false;
            for (var j = 0; j < discardedCardKinds.length; j++) {
              if (discardedCardKinds[j] == kind) {
                isDiscarded = true;
                break;
              }
            }
            if (!isDiscarded) {
              discardedCardKinds.push(kind);
            }
        }
      }

	  var discardedKindsText = [];

	  for (i = 0; i < discardedCardKinds.length; i++) {
		  discardedKindsText.push(deck[discardedCardKinds[i]]);
	  }

	  $('#discarded').find('span').text(discardedKindsText.join(', '));

      // console.log(players[0]);
      // console.log(playerOneCards);
      // console.log(playerTwoCardCount);
      // console.log(playerThreeCardCount);
      // console.log(playerFourCardCount);
      // console.log(tableCardCount);
      // console.log(discardedCardKinds);

      // How much overlap can playerOne's cards have and still fit on the screen?
      cardDisplayWidth = ((playerOneCards.length - 1) * defaultOverlap) + 79;
      if (cardDisplayWidth > canvas.width) {
        overlap = (canvas.width - cardWidth)/(playerOneCards.length - 1);
        cardDisplayWidth = ((playerOneCards.length - 1) * overlap) + 79;
      }

      //Draw the cards
      drawCards();
    }

    function drawCardsOnCanvas() {
      // draw the cards
      for (var i = cards.length - 1; i >= 0; i--) {
        context.drawImage(this, cards[i][0], cards[i][1], cardWidth, cardHeight, cards[i][2], cards[i][3], cardWidth, cardHeight);
      }

    }

	// initial state of canvas before game starts
	context.fillStyle="#003300";
    context.fillRect(canvas.offsetLeft,canvas.offsetTop,canvas.width,canvas.height);
	context.fillStyle = "#ffffff";
    context.font = "bold 24px Arial";
	context.fillText("Waiting for players", 280, 312);

    function drawCards() {
      // clear the canvas
      context.fillStyle="#003300";
      context.fillRect(canvas.offsetLeft,canvas.offsetTop,canvas.width,canvas.height);
      
      // Empty the array of card information
      cards = [];

      // Loop through the player's cards and find the corresponding area of the
      // 'cards.png' sprite sheet, and work out where each card should appear.
      // Add this to the array of card information
      for (var i = 0; i < playerOneCards.length; i++) {
        var sourceX = (playerOneCards[i] % 13) * cardWidth;
        var sourceY = (Math.floor(playerOneCards[i] / 13)) * cardHeight;
        var destX = i * overlap;
        var destY = 450;
        for (var j = 0; j < selectedCardIndexes.length; j++) {
          if (selectedCardIndexes[j] == i) {
            destY = 430;
            break;
          }
        }
        cards.push(new Array(sourceX, sourceY, destX, destY));
      }

      // locate the card back image in the cards sprite sheet.
      sourceX = 2 * cardWidth;
      sourceY = 4 * cardHeight;

      // Now loop through the other entities on the table creating records
      // for each card that needs to appear face down.

      // Player 2
      destX = 0;
      for (i = 0; i < playerTwoCardCount; i++) {
        destY = (i * backOverlap) + 27;
        cards.push(new Array(sourceX, sourceY, destX, destY));
      }

      // Player 3
      destY = 27;
      for (i = 0; i < playerThreeCardCount; i++) {
        destX = (i * backOverlap) + 150;
        cards.push(new Array(sourceX, sourceY, destX, destY));
      }

      // Player 4
      destX = 650;
      for (i = 0; i < playerFourCardCount; i++) {
        destY = (i * backOverlap) + 27;
        cards.push(new Array(sourceX, sourceY, destX, destY));
      }

      // Table
      destY = 240;
      for (i = tableCardCount; i > 0; i--) {
        destX = (i * backOverlap) + 250;
        cards.push(new Array(sourceX, sourceY, destX, destY));
      }

      // Discarded
      // TODO: Where/how are we displaying this information?

      // Create an image object for the cards
      var card = new Image();
      card.addEventListener('load', drawCardsOnCanvas, false);  
      card.src = '##TP_STUFF_URL##cards.png';

      // Write the players' names on the board
	  
	  players[0].x = 0;
	  players[0].y = 590;
	  players[1].x = 0;
	  players[1].y = 20;
	  players[2].x = 150;
	  players[2].y = 20;
	  players[3].x = 650;
	  players[3].y = 20;

      context.font = "bold 12px Arial";
	  
		for (i = 0; i < players.length; i++) {
			if (players[i].user_id == currentPlayer) {
				context.fillStyle = "#ff0000";
				// Update the current player name on the dashboard	
				$('#player').find('span').text(players[i].name);
			} else {
	  			context.fillStyle = "#ffffff";
			}
			context.fillText(players[i].name, players[i].x, players[i].y);
		}
    }

    function selectCard(event) {
		// A player can play at most 3 cards in a turn
		var maxCards = 3

		// TODO: You currently can't click the top 20 px of a card when it is above the line of cards.
		// This is a bit tricky to implement as the rules for overlap for the part poking out are different
		// to the rules for the bottom part, so an extra bit of logic would need to be added.
	  
	  	if (turn) {

			var totalOffsetX = 0;
			var totalOffsetY = 0;
			var canvasX = 0;
			var canvasY = 0;
			var currentElement = this;

			do {
				totalOffsetX += currentElement.offsetLeft;
				totalOffsetY += currentElement.offsetTop;
			} while(currentElement = currentElement.offsetParent)

			canvasX = event.pageX - totalOffsetX;
			canvasY = event.pageY - totalOffsetY;

			if (canvasY >= 450 && canvasY <= 450 + cardHeight && canvasX <= cardDisplayWidth) {
				// Assume player clicked the first card
				var cardClicked = 0;
				// If their mouse x position is further across than the first card, then work out which card they clicked
				if (canvasX > cardWidth) {
					cardClicked = Math.ceil((canvasX - cardWidth)/overlap);
				}
				// Now work out if the user was selecting or deselecting a card
				var processedCard = false;
				for (var i = 0; i < selectedCardIndexes.length; i++) {
					if (cardClicked == selectedCardIndexes[i]) {
						selectedCardIndexes.splice(i, 1);
						selectedCardNumbers.splice(i, 1);
						processedCard = true;
					}
				}
				if (!processedCard && selectedCardIndexes.length < maxCards) {
					selectedCardIndexes.push(cardClicked);
					selectedCardNumbers.push(playerOneCards[cardClicked]);
				}
	
				console.log(selectedCardIndexes);
				console.log(selectedCardNumbers);
			
				// Now redraw the board to show which cards are now selected.
				drawCards();
			}
		}
	}

    function getSelectedCards() {
      return selectedCardNumbers;
    }

    canvas.addEventListener('click', selectCard, false);       



});
