namespace eval CHEAT {

	asSetAct CHEAT_disp_rooms           [namespace code disp_rooms]
	asSetAct CHEAT_join_game            [namespace code join_game]
	asSetAct CHEAT_reg_user             [namespace code reg_user]
	asSetAct CHEAT_disp_reg_form        [namespace code disp_reg_form]
	asSetAct CHEAT_start_game           [namespace code start_game]
	asSetAct CHEAT_check_status         [namespace code check_status]
	asSetAct CHEAT_play_action          [namespace code play_action]
	asSetAct CHEAT_cheat_action         [namespace code cheat_action]
	asSetAct CHEAT_four_players         [namespace code four_players]
	asSetAct CHEAT_timeout_action       [namespace code timeout_action]

global PLAYERS DEBUG

# DEBUG variable => 0:disabled;1:enabled
proc debug {} {
	global DEBUG
	set DEBUG 0 
}

proc check_player_won {cards} {
	global PLAYERS DEBUG
	debug

	for {set i 0} {$i < 4} {incr i} {
		if {[lsearch $cards $PLAYERS($i,player_id)] < 0} {
                	return [list $PLAYERS($i,player_id) $PLAYERS($i,name)]
		}
	}
        return -1
}

proc play_action {} {
	global DB DEBUG
	debug
	set user_id      [reqGetArg user_id]
	set game_id      [reqGetArg game_id]
	set cards_played [reqGetArg cards]
	set kind         [reqGetArg kind] 
	set log_message  [reqGetArg log_message]

	ob::log::write ERROR "------------------- cards played: $cards_played"

	set sql {
		select first 1
			cards,
			kind,
			turn_no,
			action
		from
			tTurn
		where
			game_id = ?
		order by
			turn_no desc
	}

	if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
		ob::log::write ERROR {===>error: $msg}
		return
	}
	if {[catch {set rs [inf_exec_stmt $stmt $game_id]} msg]} {
		ob::log::write ERROR {===>error: $msg}
		catch {inf_close_stmt $stmt}
		return
	}
	catch {inf_close_stmt $stmt}

	set cards   [db_get_col $rs 0 cards]
	set last_kind    [db_get_col $rs 0 kind]
	set turn_no [db_get_col $rs 0 turn_no]
	set last_action  [db_get_col $rs 0 action]

	if {$DEBUG==1} {ob::log::write ERROR "the last turn was: $turn_no"}

        catch {db_close $rs}

	set cards         [split [string trim $cards "\[\]"] ","]

	if {$DEBUG==1} {ob::log::write ERROR "-------------------------- cards: $cards"}

	set cards_played  [split $cards_played ","]

	if {$DEBUG==1} {ob::log::write ERROR "cards played: $cards_played"}

	foreach cp $cards_played {
		set cards [lreplace $cards $cp $cp 0] 
	} 

	if {$DEBUG==1} {ob::log::write ERROR "now the cards are: $cards"}

	set json_cards [join $cards ","]
	set json_cards "\[$json_cards\]"

	incr turn_no

	if {$DEBUG==1} {ob::log::write ERROR "the current turn is: $turn_no"}

	set action {play cards}

	set player_id [get_next_player $user_id $game_id]
	
	get_players $game_id
	set winner_id -1
	set player_has_won [check_player_won $cards]
	if {[lindex $player_has_won 0] > -1 && [lindex $player_has_won 0] != $user_id} {
		ob::log::write INFO "$player_has_won has won!"
		append log_message " [lindex $player_has_won 1] has won!"
		set winner_id [lindex $player_has_won 0]
		set_winner $game_id $winner_id
	}

	# Now we can insert the turn into the databse
	set sql {
		insert into tTurn
			(game_id,
			user_id,
			turn_no,
			cards,
			action,
			kind,
			log_message)
		values
			(?,?,?,?,?,?,?)
	}

	if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
		ob::log::write ERROR {===>error: $msg}
		return
	}

	if {[catch [inf_exec_stmt $stmt $game_id $player_id $turn_no $json_cards $action $kind $log_message] msg]} {
		ob::log::write ERROR {===>error: $msg}
		catch {inf_close_stmt $stmt}
		return
	} else {
		ob::log::write ERROR {===>successfully inserted data}
	}
	catch {inf_close_stmt $stmt}
	
	create_json_response $game_id $json_cards $kind $player_id $turn_no 0 $user_id $log_message $winner_id
}

proc join_game {} {
	global DB DEBUG
	debug

        set game_id [reqGetArg game_id]
        set user_id [reqGetArg user_id]

        set sql {
                insert into tGamePlayers
                        (game_id,
                        user_id
                        )
                values
                        (?,?)
        }

        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
                tpBindString err_msg "error occured while preparing statement"
                ob::log::write ERROR {===>error: $msg}
                tpSetVar err 1
                asPlayFile -nocache training/cheat/cheat_main.html
                return
        }

        if {[catch {set rs [inf_exec_stmt $stmt $game_id $user_id]} msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache training/cheat/cheat_main.html
                return
        }

        tpBindString GAME_ID $game_id
        tpBindString USER_ID $user_id	
        catch {inf_close_stmt $stmt}

	four_players $game_id

        asPlayFile -nocache training/cheat/cheat_main.html
}

proc four_players  {game_id} {
	global DB DEBUG
	debug


        set sql {
                select
                        COUNT(*) as players
                from
                        tGamePlayers
                where
                        game_id=?
        }
        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
                tpBindString err_msg "error occured while preparing statement $sql"
                ob::log::write ERROR {===>error: $msg}
                tpSetVar err 1
                asPlayFile -nocache training/errors.html
                return
        }
        if {[catch {set rs [inf_exec_stmt $stmt $game_id]} msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache training/errors.html
                return
        }
        set players [db_get_col $rs 0 players]

        catch {inf_close_stmt $stmt}
	catch {db_close $rs}

        tpSetVar     num_players  $players
        
	if {$players == 4} {

	# memorize the current game_id in order to set correctly the next game_id
        set sql {
                update tGame
                set
                        outcome="Used"
                where
                        game_id=?
        }
        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
                ob::log::write ERROR {===>error: $msg}
                return
        }
        if {[catch {set rs [inf_exec_stmt $stmt $game_id]} msg]} {
                ob::log::write ERROR {===>error: $msg}
                return
        }
        catch {inf_close_stmt $stmt}
        catch {db_close $rs}
	
		# create the new game for next 4 gamers
		set sql {
			insert
				into
				tGame (outcome)
				values
				("New")
		}
		if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			ob::log::write ERROR {===>error: $msg}
			return
		}
		if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
			ob::log::write ERROR {===>error: $msg}
			catch {inf_close_stmt $stmt}
			return
		}
		catch {inf_close_stmt $stmt}
		catch {db_close $rs}

		# start the game 
		start_game 
        }
}
	
proc disp_reg_form {} {
	global DEBUG
	debug
	asPlayFile -nocache training/cheat/registration_form.html
}

proc reg_user {} {
	global DB DEBUG
	debug

	set username [reqGetArg username]
	set password [reqGetArg password]
	set name     [reqGetArg firstname]
	set surname  [reqGetArg surname]

	set sql {
		insert into tUsers 
			(name,
			surname,
			username,
			password,
			logged)
		values
			(?,?,?,?,1)
	}

	if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
		tpBindString err_msg "error occured while preparing statement"
		ob::log::write ERROR {===>error: $msg}
		tpSetVar err 1
		asPlayFile -nocache training/drilldown-events.html
		return
	}

	if {[catch {set rs [inf_exec_stmt $stmt $name $surname $username $password]} msg]} {
		tpBindString err_msg "error occured while executing query"
		ob::log::write ERROR {===>error: $msg}
		catch {inf_close_stmt $stmt}
		tpSetVar err 1
		asPlayFile -nocache training/drilldown-events.html
		return
	}
	
	 set user_id [inf_get_serial $stmt]
	 
	 disp_rooms $user_id
 }

proc disp_rooms {{user_id 0}} {

	global DB
	
	if {$user_id == 0} {
		set user_id [reqGetArg user_id]
	}

    tpBindString USER_ID $user_id

	catch {inf_close_stmt $stmt}
	
	 set gameSql {
     	select
        	max(game_id) game_id
        from
			tGame
        }

        if {[catch {set stmt [inf_prep_sql $DB $gameSql]} msg]} {
        	tpBindString err_msg "error occured while preparing statement"
            ob::log::write ERROR {===>error: $msg}
            tpSetVar err 1
            asPlayFile -nocache training/cheat/disp_rooms.html
            return
        }

        if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
        	tpBindString err_msg "error occured while executing query"
            ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
            tpSetVar err 1
            asPlayFile -nocache training/cheat/disp_rooms.html
            return
        }

	set game_id [db_get_col $rs 0 game_id]

    catch {inf_close_stmt $stmt}
	catch {db_close $rs}

    tpBindString GAME_ID $game_id

	puts "disp rooms: user_id: $user_id game_id: $game_id"

	asPlayFile -nocache training/cheat/disp_rooms.html
}

proc get_players {game_id} {
	global PLAYERS DB DEBUG
	debug

	set stm_get_players {
		select 
			p.user_id,
			u.name
		from
			tGamePlayers p,
			tUsers u
		where 
			p.user_id = u.user_id and
			p.game_id = ?
		order by
			user_id
	}

    if {[catch {set stmt [inf_prep_sql $DB $stm_get_players]} msg]} {
    	tpBindString err_msg "error occured while preparing statement"
        ob::log::write ERROR {===>error: $msg}
        tpSetVar err 1
        asPlayFile -nocache training/cheat/registration_form.html
        return
    }

    if {[catch {set rs [inf_exec_stmt $stmt $game_id]} msg]} {
	    tpBindString err_msg "error occured while executing query"
        ob::log::write ERROR {===>error: $msg}
        catch {inf_close_stmt $stmt}
        tpSetVar err 1
        asPlayFile -nocache training/cheat/registration_form.html
        return
    }

    if {$DEBUG ==1} {ob::log::write ERROR "------------------ sql: $stm_get_players , param: $game_id"}

    catch {inf_close_stmt $stmt}

    if {$DEBUG ==1} {ob::log::write ERROR "----------------- [db_get_nrows $rs]"}

	set num_players [db_get_nrows $rs]

	tpSetVar num_players $num_players
	tpBindString players_count "There are $num_players players."

	for {set i 0} {$i < $num_players} {incr i} {
		set PLAYERS($i,player_id) [db_get_col $rs $i user_id]
		set PLAYERS($i,name)      [db_get_col $rs $i name]
	}

	if {$DEBUG ==1} {ob::log::write ERROR "--------------- [array get PLAYERS]"}

	catch {db_close $rs}

	tpBindVar PLAYER_ID   PLAYERS player_id player_idx
}

proc start_game {} {
	global PLAYERS DEBUG DB
	debug

	set user_id [reqGetArg user_id]
	set game_id [reqGetArg game_id]

	get_players $game_id

	# Create an array of cards
	set playing_cards []
	set cards []

	for {set i 0} {$i < 52} {incr i} {
		lappend playing_cards $i
		lappend cards $i
	}

	# Shuffle the cards
	for {set i 0} {$i < [llength $playing_cards]} {incr i} {
		set j [expr {int(rand()*52)}]
		set temp [lindex $playing_cards $j]
		lset playing_cards $j [lindex $playing_cards $i]
		lset playing_cards $i $temp
	}

	# Now create the cards array for the game
	set player_index -1
	for {set i 0} {$i < [llength $playing_cards]} {incr i} {
		if {[expr $i % 13] == 0} {
			incr player_index
		}
		set card [lindex $playing_cards $i]
		lset cards $card $PLAYERS($player_index,player_id)
	}

	# If any player has 4 of a kind, discard these cards
	set cards [discard_four_of_a_kind $cards]

	set json_cards [join $cards ","]
	set json_cards "\[$json_cards\]"

	set action "start game"
	set kind -1
	set log_message "Welcome to cheat game $game_id"

	set stm_start_game {
		insert into tTurn
			(game_id,
			user_id,
			turn_no,
			cards,
			action,
			kind,
			log_message)
		values
			(?,?,0,?,?,?,?)
	}

	if {[catch {set stmt [inf_prep_sql $DB $stm_start_game]} msg]} {
		tpBindString err_msg "error occured while preparing statement"
		ob::log::write ERROR {===>error: $msg}
		tpSetVar err 1
		asPlayFile -nocache training/cheat/registration_form.html
		return
	}

	if {[catch {set rs [inf_exec_stmt $stmt $game_id $PLAYERS(0,player_id) $json_cards $action $kind $log_message]} msg]} {
		tpBindString err_msg "error occured while executing query"
		ob::log::write ERROR {===>error: $msg}
		catch {inf_close_stmt $stmt}
		tpSetVar err 1
		asPlayFile -nocache training/cheat/registration_form.html
		return
	}

	catch {inf_close_stmt $stmt}
}

proc create_json_response {game_id cards kind cur_player_id turn_no new_round user_id log_message winner_id} {

	global PLAYERS DEBUG
	debug

	if {$DEBUG == 1} {ob::log::write ERROR {------------------------- cards: $cards}}

	set response "
	{
		\"game_id\": $game_id,
		\"cards\": $cards, 
		\"kind\": $kind,
		\"players\": \[
			{\"user_id\": $PLAYERS(0,player_id), \"name\": \"$PLAYERS(0,name)\"},
			{\"user_id\": $PLAYERS(1,player_id), \"name\": \"$PLAYERS(1,name)\"},
			{\"user_id\": $PLAYERS(2,player_id), \"name\": \"$PLAYERS(2,name)\"},
			{\"user_id\": $PLAYERS(3,player_id), \"name\": \"$PLAYERS(3,name)\"}
		\],
		\"cur_player_id\": $cur_player_id,
		\"turn_no\": $turn_no,
		\"new_round\": $new_round,
		\"log_message\": \"$log_message\",
		\"winner_id\": $winner_id
	}"

	set chan [open "training/cheat/$user_id.json" w+]
	puts $chan $response 
	close $chan

	asPlayFile -nocache "training/cheat/$user_id.json"
}

proc check_status {} {
	global DB DEBUG
	debug

	set user_id [reqGetArg user_id]
	set game_id [reqGetArg game_id]
	set turn_no [reqGetArg turn_no]

	set stm_get_last_turn {
		select first 1
			t.cards,
			t.action,
			t.kind,
			t.user_id,
			t.log_message,
			t.turn_no as last_turn
		from
			tTurn t
		where
			t.game_id = ?
		order by
			t.turn_no desc
			
	}

    if {[catch {set stmt [inf_prep_sql $DB $stm_get_last_turn]} msg]} {
	    tpBindString err_msg "error occured while preparing statement"
        ob::log::write ERROR {===>error: $msg}
        tpSetVar err 1
        return
    }

    if {[catch {set rs [inf_exec_stmt $stmt $game_id]} msg]} {
    	tpBindString err_msg "Not enough players"
		catch {inf_close_stmt $stmt}
		set last_turn 0
        set cards     ""
        set action    ""
        set kind      ""
        set player_id      ""
		set log_message ""
		set winner_id ""
	} 

	catch {inf_close_stmt $stmt}
	
	if {[db_get_nrows $rs] > 0} {
		set last_turn [db_get_col $rs 0 last_turn]
        set cards     [db_get_col $rs 0 cards]
        set action    [db_get_col $rs 0 action]
        set kind      [db_get_col $rs 0 kind]
        set player_id [db_get_col $rs 0 user_id]
		set log_message [db_get_col $rs 0 log_message]

		set sql {
			select
				outcome
			from
				tGame
			where
				game_id = ?
		}

		if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			ob::log::write ERROR {===>error: $msg}
			return
		}
		if {[catch {set rs [inf_exec_stmt $stmt $game_id]} msg]} {
			ob::log::write ERROR {===>error: $msg}
			catch {inf_close_stmt $stmt}
		}

		catch {inf_close_stmt $stmt}
			
		set winner_id -1
		set outcome [db_get_col $rs 0 outcome]
		set isNumeric {^[0-9]*$}
		if {[regexp $isNumeric $outcome]} {
			set winner_id $outcome
		}
	} else {
		set last_turn 0
	    set cards     ""
        set action    ""
        set kind      ""
        set player_id      ""
		set log_message ""
		set winner_id ""
	}

	set new_round 0

	if {$kind == -1 || $action == "call cheat" || $action == "timeout"} {
		set new_round 1
	}

	if {$DEBUG == 1} {ob::log::write ERROR "Turn no. from client: $turn_no . Current turn no: $last_turn"}
	
	get_players $game_id
	create_json_response $game_id $cards $kind $player_id $last_turn $new_round $user_id $log_message $winner_id
}

#returns indexes of cards played in the last_turn aka turn_1
proc diff { turn_1 turn_2 } {
	set cards_played []
	for {set i 0} {$i < [llength $turn_1]} {incr i} {
		if { [lindex $turn_1 $i] == 0 && [lindex $turn_2 $i] != 0 } {
			lappend cards_played $i
		}
	}
	return $cards_played
}

#returns a boolean, cards must be a list of indexes of the cards played in the previous turn
proc cheated { cards kind } {
	for {set i 0} {$i < [llength $cards]} {incr i} {
		if { [lindex $cards $i] % 13 != $kind } { return true }
	}
	return false
}

proc cheat_action {} {
	
	global DB DEBUG PLAYERS
	debug

	set user_id [reqGetArg user_id]
	set game_id [reqGetArg game_id]
	set log_message [reqGetArg log_message]

	set has_cheated 0
	set sql {
		select first 2
			cards,
			kind,
			user_id,
			turn_no
		from
			tTurn
		where
			game_id = ?
		order by
			turn_no desc
	}

	if {[catch {set statement [inf_prep_sql $DB $sql]} msg]} {
		ob::log::write ERROR {===>error: $msg}
		return
	}

	if {[catch {set results [inf_exec_stmt $statement $game_id]} msg]} {
		ob::log::write ERROR {===>error: $msg}
		catch {inf_close_stmt $statement}
		return
	}
	catch {inf_close_stmt $statement}

	set cards_played_on_turns []

	# Get the kind of cards played in the previous turn
	set kind_played_last_turn [db_get_col $results 0 kind]
	
	# Get the ID of the previous player (first row not second, it's the last turn player that we want to track)
	set previous_player_id [db_get_col $results 1 user_id]  

	# Get the number of the previous turn
	set previous_turn_no [db_get_col $results 0 turn_no]

	# Put the cards from the previous 2 turns in the turns list
	for {set i 0} {$i < [db_get_nrows $results]} {incr i} {
		set cards [db_get_col $results $i cards]
		set cards [split [string trim $cards \"\[\] ] ","]
		lappend cards_played_on_turns $cards
	}

	puts $cards_played_on_turns

	set cards_played_last_turn [ diff [lindex $cards_played_on_turns 0] [lindex $cards_played_on_turns 1] ]
	
	set cards [lindex $cards_played_on_turns 0] 
	puts "cards after-diff: $cards and indexes $cards_played_last_turn"
	
	set indexes [lsearch -all $cards 0]
	if { [cheated $cards_played_last_turn $kind_played_last_turn] } {
			puts "Player $previous_player_id cheated!"
			for {set i 0} {$i < [llength $indexes]} {incr i} {
				set cards [lreplace $cards [lindex $indexes $i] [lindex $indexes $i] $previous_player_id] 	
			}
			set has_cheated 1
		} else {
			puts "Player $user_id was wrong!"
			for {set i 0} {$i < [llength $indexes]} {incr i} {
				set cards [lreplace $cards [lindex $indexes $i] [lindex $indexes $i] $user_id] 	
			}
		}
    
	puts "cards_played_last_turn after-work: $cards and indexes $indexes"
    set next_turn_cards $cards

	# If any player has 4 of a kind, discard these cards
	set next_turn_cards [discard_four_of_a_kind $next_turn_cards]	

	set turn_no [incr previous_turn_no]
	set action "call cheat"
	
	set json_cards [join $next_turn_cards ","]
	set json_cards "\[$json_cards\]"

	# If the previous player cheated, then the current player gets
	# another turn. If not, then play moves on to the next player.
	set next_player_id 0

	get_players $game_id

	set previous_player_name ""
	set current_player_name ""

	for {set i 0} {$i < 4} {incr i} {
		if {$PLAYERS($i,player_id) == $previous_player_id} {
			set previous_player_name $PLAYERS($i,name)
		} elseif {$PLAYERS($i,player_id) == $user_id} {
			set current_player_name $PLAYERS($i,name)
		}
	}
	
	if {$has_cheated} {
		append log_message " $previous_player_name cheated! $previous_player_name has picked up all the cards on the table. $current_player_name gets another turn."
		set next_player_id $user_id
	} else {
		set next_player_id [get_next_player $user_id $game_id]
		append log_message " $previous_player_name didn't cheat! $current_player_name picked up all the cards on the table."
	}
	
	set winner_id -1
	set player_has_won [check_player_won $next_turn_cards]
	if {[lindex $player_has_won 0] > -1} {
		ob::log::write INFO "$player_has_won has won!"
		append log_message " [lindex $player_has_won 1] has won!"
		set winner_id [lindex $player_has_won 0]
		set_winner $game_id $winner_id
	}

	# Now we can insert the turn into the databse
	set sql {
		insert into tTurn
			(game_id,
			user_id,
			turn_no,
			cards,
			action,
			kind,
			log_message)
		values
			(?,?,?,?,?,?,?)
	}

	if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
		tpBindString err_msg "error occured while preparing statement"
		ob::log::write ERROR {===>error: $msg}
		tpSetVar err 1
		asPlayFile -nocache training/cheat/cheat_main.html
		return
	}

	if {[catch {set rs [inf_exec_stmt $stmt $game_id $next_player_id $turn_no $json_cards $action $kind_played_last_turn $log_message]} msg]} {
		tpBindString err_msg "error occured while executing query"
		ob::log::write ERROR {===>error: $msg}
		catch {inf_close_stmt $stmt}
		tpSetVar err 1
		asPlayFile -nocache training/cheat/cheat_main.html
		return
	}
	catch {inf_close_stmt $stmt}

	# Now we can create all the info to pass back to the frontend	
	create_json_response $game_id $json_cards $kind_played_last_turn $next_player_id $turn_no 1 $user_id $log_message $winner_id
}

proc discard_four_of_a_kind {cards} {
	# Now loop through and see if any player has 4 of a kind.
	# If they do, then assign these to discarded (-1)
	for {set i 0} {$i < [expr [llength $cards] / 4]} {incr i} {
		set clubs $i
		set diamonds [expr $i + 13]
		set hearts [expr $i + 26]
		set spades [expr $i + 39]
		set players_with_kind [list [lindex $cards $clubs] [lindex $cards $diamonds] [lindex $cards $hearts] [lindex $cards $spades]]
		set players_with_kind [lsort -unique $players_with_kind]
		if {[llength $players_with_kind] == 1 && [lindex $players_with_kind 0] > 0} {
			# This player has 4 of a kind, so discard them
			lset cards $clubs -1
			lset cards $diamonds -1
			lset cards $hearts -1
			lset cards $spades -1
		}
	}
	return $cards
}

proc get_next_player {current_player_id game_id} {
	global DB DEBUG
	debug

	set next_player_id 0

	# 1. Fetch all the players in the game
	set sql {
		select
			user_id
		from
			tGamePlayers
		where
			game_id = ?
		order by
			user_id
	}

	set statement [inf_prep_sql $DB $sql]
	set results [inf_exec_stmt $statement $game_id]
	inf_close_stmt $statement
		
	set game_players []

	for {set i 0} {$i < [db_get_nrows $results]} {incr i} {
		lappend game_players [db_get_col $results $i user_id]
	}

	set next_player_id 0

	# 2. Find the first player whose ID is larger than the
	# current player's id. This is the next player
	for {set i 0} {$i < [llength $game_players]} {incr i} {
		if {[lindex $game_players $i] > $current_player_id} {
			set next_player_id [lindex $game_players $i]
			break
		}
	}

	# If no player has an ID that is bigger than the 
	# current players ID, then set it as the smallest one
	# (i.e. go from player 4 to player 1)
	if {$next_player_id == 0} {
		set next_player_id [lindex $game_players 0]
	}

	ob::log::write ERROR "----------------- current player: $current_player_id , next player: $next_player_id"

	return $next_player_id
}

proc timeout_action {} {
	global DB

	set user_id [reqGetArg user_id]
	set game_id [reqGetArg game_id]
	set log_message [reqGetArg log_message]

	set sql {
		select first 1 
			cards,
			kind,
			turn_no
		from
			tTurn
		where
			game_id = ?
		order by
			turn_no desc
	}

	# Get the cards from the previous turn
	if {[catch {set statement [inf_prep_sql $DB $sql]} msg]} {
		ob::log::write ERROR {===>error: $msg}
		return
	}

	if {[catch {set results [inf_exec_stmt $statement $game_id]} msg]} {
		ob::log::write ERROR {===>error: $msg}
		catch {inf_close_stmt $statement}
		return
	}
	catch {inf_close_stmt $statement}

	set cards []

	for {set i 0} {$i < [db_get_nrows $results]} {incr i} {
		set cards [db_get_col $results $i cards]
		set cards [split [string trim $cards \"\[\] ] ","]
	}

	set kind_played_last_turn [db_get_col $results 0 kind]
	set previous_turn_no      [db_get_col $results 0 turn_no]

	set indexes [lsearch -all $cards 0]

	# Assign them all to the current user
	for {set i 0} {$i < [llength $indexes]} {incr i} {
		set cards [lreplace $cards [lindex $indexes $i] [lindex $indexes $i] $user_id] 	
	}
	
	# If any player has 4 of a kind, discard these cards
	set cards [discard_four_of_a_kind $cards]
	
	set turn_no [incr previous_turn_no]
	set action "timeout"
	
	set json_cards [join $cards ","]
	set json_cards "\[$json_cards\]"

	set next_player_id [get_next_player $user_id $game_id]

	set winner_id -1
	set player_has_won [check_player_won $cards]
	if {[lindex $player_has_won 0] > -1} {
		ob::log::write INFO "$player_has_won has won!"
		append log_message " [lindex $player_has_won 1] has won!"
		set winner_id [lindex $player_has_won 0]
		set_winner $game_id $winner_id
	}

	# Now we can insert the turn into the databse
	set sql {
		insert into tTurn
			(game_id,
			user_id,
			turn_no,
			cards,
			action,
			kind,
			log_message)
		values
			(?,?,?,?,?,?,?)
	}

	if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
		tpBindString err_msg "error occured while preparing statement"
		ob::log::write ERROR {===>error: $msg}
		tpSetVar err 1
		asPlayFile -nocache training/cheat/cheat_main.html
		return
	}

	if {[catch {set rs [inf_exec_stmt $stmt $game_id $next_player_id $turn_no $json_cards $action $kind_played_last_turn $log_message]} msg]} {
		tpBindString err_msg "error occured while executing query"
		ob::log::write ERROR {===>error: $msg}
		catch {inf_close_stmt $stmt}
		tpSetVar err 1
		asPlayFile -nocache training/cheat/cheat_main.html
		return
	}
	catch {inf_close_stmt $stmt}

	# Now we can create all the info to pass back to the frontend	
	create_json_response $game_id $json_cards $kind_played_last_turn $next_player_id $turn_no 1 $user_id $log_message $winner_id

}

proc set_winner {game_id winner_id} {
	
	puts "+++++++++++++++++ $winner_id"
	
	global DB

	set sql {
		update tGame
        set
           	outcome=?
        where
           	game_id=?
    }
	if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
		ob::log::write ERROR {===>error: $msg}
		return
	}
	if {[catch {set results [inf_exec_stmt $stmt $winner_id $game_id]} msg]} {
		ob::log::write ERROR {===>error: $msg}
		catch {inf_close_stmt $stmt}
		return
	}
	catch {inf_close_stmt $stmt}
}
}
