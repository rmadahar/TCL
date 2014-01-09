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
	asSetAct CHEAT_json_encode          [namespace code json_encode_game_state]

# cards is tcl list, players is tcl list of tcl arrays player(user_id, name)
#proc json_encode_game_state {game_id cards kind players cur_player_id turn_no new_round}
proc json_encode_game_state {} {

        set json_string ""

        append json_string {"game_id":}
        append json_string $game_id
        append json_string {,"cards":[}
        foreach c $cards {
               append json_string $c,
        }
        set json_string [string trimright $json_string ,]

        append json_string {],"kind":}
        append json_string $kind
        append json_string {,"players":[}

        foreach p $players {
                set usr {"user_id":}
                append usr [lindex $p 1],
                append usr {"name":}
                append usr [lindex $p 3]
                append json_string "{$usr},"
        }
        set json_string [string trimright $json_string ,]

        append json_string {],"cur_player_id":}
        append json_string $cur_player_id
        append json_string {,"turn_no":}
        append json_string $turn_no
        append json_string {,"new_round":}
        append json_string $new_round

        set json_string "{$json_string}"



	OT_LogWrite 1 "===================>$json_string"
	return $json_string
}

proc disp_rooms {} {
	asPlayFile -nocache training/cheat/disp_rooms.html
}

proc join_game {} {
	global DB EVENTS

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

        catch {inf_close_stmt $stmt}

        asPlayFile -nocache cheat/cheat_main.html
}

proc four_players {} {

        global DB

        set sql {
                select
                        COUNT(*) as players
                from
                        tUsers
                where
                        logged='1'
        }
        if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
                tpBindString err_msg "error occured while preparing statement $sql"
                ob::log::write ERROR {===>error: $msg}
                tpSetVar err 1
                asPlayFile -nocache training/errors.html
                return
        }
        if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache training/errors.html
                return
        }
        set players [db_get_col $rs 0 players]

        catch {inf_close_stmt $stmt}

        tpSetVar     num_players  $players
        if {$players = 4} {
			start_game 
        }
        asPlayFile -nocache training/cheat/cheat_main.html
}
	
proc disp_reg_form {} {
	asPlayFile -nocache training/cheat/registration_form.html
}

proc reg_user {} {
	global DB EVENTS

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
		asPlayFile -nocache training/cheat/disp_rooms.html
		return
	}

	if {[catch {set rs [inf_exec_stmt $stmt $name $surname $username $password]} msg]} {
		tpBindString err_msg "error occured while executing query"
		ob::log::write ERROR {===>error: $msg}
		catch {inf_close_stmt $stmt}
		tpSetVar err 1
		asPlayFile -nocache training/cheat/disp_rooms.html
		return
	}

	set user_id [inf_get_serial $stmt]

        tpBindString USER_ID $user_id

	 catch {inf_close_stmt $stmt}

	

	set gameSql {
			select
				max(game_id) 
			from 	tGame
		     }	


	 if {[catch {set stmt [inf_prep_sql $DB $gameSql]} msg]} {
                tpBindString err_msg "error occured while preparing statement"
                ob::log::write ERROR {===>error: $msg}
                tpSetVar err 1
                asPlayFile -nocache training/cheat/disp_rooms.html
                return
        }

        if {[catch {set rs [inf_exec_stmt $stmt $game_id]} msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache training/cheat/disp_rooms.html
                return
        }

	
	set game_id [inf_get_serial $stmt]

        tpBindString GAME_ID $game_id

	catch {inf_close_stmt $stmt}

	asPlayFile -nocache training/cheat/disp_rooms.html
}

proc start_game {} {
	global PLAYERS

	set user_id [reqGetArg user_id]
	set game_id [reqGetArg game_id]

	set stm_get_players {
		select 
			p.user_id as player_id,
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

        catch {inf_close_stmt $stmt}

	set num_players [db_get_nrows $rs]

	tpSetVar num_players $num_classes
	tpBindString players_count "There are $num_players players."

	for {set i 0} {$i < $num_players} {incr i} {
		set PLAYERS($i,player_id) [db_get_col $rs $i player_id]
		set PLAYERS($i,name)      [db_get_col $rs $i name]
	}

	catch {db_close $rs}

	tpBindVar PLAYER_ID   PLAYERS player_id player_idx

	set max_cards 13
	set cards_player_1 0
	set cards_player_2 0
	set cards_player_3 0
	set cards_player_4 0
	set cards ""

	for {set i 0} {$i < 52} {incr i} {
		
		if {1} {
			lappend cards $PLAYERS([expr{floor(rand() * 4}],player_id)
			cards_player
		}
	}

	set action "start game"
	set kind ""

	set stm_start_game {
		insert into tTurn
			(game_id,
			user_id,
			turn_no,
			cards,
			action,
			kind)
		values
			(?,?,0,?,?,?)
	}

	if {[catch {set stmt [inf_prep_sql $DB $stm_start_game]} msg]} {
		tpBindString err_msg "error occured while preparing statement"
		ob::log::write ERROR {===>error: $msg}
		tpSetVar err 1
		asPlayFile -nocache training/cheat/registration_form.html
		return
	}

	if {[catch {set rs [inf_exec_stmt $stmt $game_id $user_id $cards $action $kind]} msg]} {
		tpBindString err_msg "error occured while executing query"
		ob::log::write ERROR {===>error: $msg}
		catch {inf_close_stmt $stmt}
		tpSetVar err 1
		asPlayFile -nocache training/cheat/registration_form.html
		return
	}

	catch {inf_close_stmt $stmt}

	create_json_response $game_id $cards -1 $PLAYERS(0,player_id) 0 1 1
}

proc create_json_response {game_id, cards, kind, cur_player_id, turn_no, new_round, players} {
	global PLAYERS

	set response "
	{
		game_id: $game_id,
		cards: $cards, 
		kind: $kind,"
	if {$players} {
		append response "
		players: [
			{user_id: $PLAYERS(0,player_id), name: \"$PLAYERS(0,name)\"},
			{user_id: $PLAYERS(1,player_id), name: \"$PLAYERS(1,name)\"},
			{user_id: $PLAYERS(2,player_id), name: \"$PLAYERS(2,name)\"},
			{user_id: $PLAYERS(3,player_id), name: \"$PLAYERS(3,name)\"}
		],"
	}
	append response "
		cur_player_id: $cur_player_id,
		turn_no: $turn_no,
		new_round: $new_round
	}"

	set chan [open "training/cheat/$user_id.json"]
	puts $chan response] 
	close $chan

	asPlayFile -nocache "training/cheat/$user_id.json"
}

proc check_status {} {
	set user_id [reqGetArg user_id]
	set game_id [reqGetArg game_id]
	set turn_no [reqGetArg turn_no]

	set stm_get_last_turn {
		select
			t.cards,
			t.action,
			t.kind
			max(t.turn_no) as last_turn,
			
		from
			tTurn t
		where
			t.user_id = ? and
			t.game_id = ?
			
	}

        if {[catch {set stmt [inf_prep_sql $DB $stm_get_last_turn]} msg]} {
                tpBindString err_msg "error occured while preparing statement"
                ob::log::write ERROR {===>error: $msg}
                tpSetVar err 1
                asPlayFile -nocache training/cheat/registration_form.html
                return
        }

        if {[catch {set rs [inf_exec_stmt $stmt $user_id $game_id]} msg]} {
                tpBindString err_msg "error occured while executing query"
                ob::log::write ERROR {===>error: $msg}
                catch {inf_close_stmt $stmt}
                tpSetVar err 1
                asPlayFile -nocache training/cheat/registration_form.html
                return
        }

        catch {inf_close_stmt $stmt}

	set last_turn [db_get_col $rs 0 last_turn]
	set cards     [db_get_col $rs 0 cards]
	set action    [db_get_col $rs 0 action]
	set kind      [db_get_col $rs 0 kind]

	if {last_turn != turn_no} {
		 create_json_response $game_id $cards $kind $player_id $turn_no 0 1
	}
}

proc play_action {} {
	asPlayFile -nocache training/cheat/cheat_main.html
}

proc cheat_action {} {
	
	set user_id [reqGetArg user_id]
	set game_id [reqGetArg game_id]

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

	set statement [inf_prep_sql $DB $sql]
	set results [inf_exec_sql $statemnet $game_id]

	inf_close_stmt $statement

	set cards_played_on_turns []

	# Get the kind of cards played in the previous turn
	set kind_played_last_turn [db_get_col $results 1 kind]
	
	# Get the ID of the previous player
	set previous_player_id [db_get_col $results 1 user_id]

	# Get the number of the previous turn
	set previous_turn_no [db_get_col $results 1 turn_no]

	# Put the cards from the previous 2 turns in the turns list
	for {set i 0} {i < [db_get_nrows $results} {incr i} {
		set cards [db_get_col $results $i cards]
		lappend cards_played_on_turns $cards
	}

	db_close $results

	set cards_played_last_turn []

	# Compare the previous two turns. If an entry does not match
	# put its index (the card number) into the cards_played list
	for {set i 0} {$i < [llength [lindex $cards_played_on_turns 0]]} {incr i} {
		if {[lindex $turns 0 $i] != [lindex $cards_played_on_turns 1 $i]} {
			lappend cards_played_last_turn $i
		}
	}

	set has_cheated 0

	# For each card in cards_played, find the kind of the card
	# and check if it is the same as the kind fetched from the DB.
	# If it is not the same, the player cheated.
	for {set i 0} {$i < [llength $cards_played_last_turn]} {incr i} {
		set kind_of_card [expr [lindex $cards_played_last_turn $i] % 13]
		if {$kind_of_card != $kind_played_last_turn} {
			set has_cheated 1
			break
		}
	}

	# Make the next turn a copy of the previous turn
	set next_turn_cards [lindex $cards_played_on_turns 1]

	# Reassign cards from table to the previous player if
	# they cheated, or to the current player if they didn't
	# cheat
	for {set i 0} {$i < [llength $next_turn_cards]} {incr i} {
		if {[lindex $next_turn_cards $i] == 0} {
			if {cheat} {
				lset next_turn_cards $i $previous_player_id
			} else {
				lset next_turn_cards $i $user_id
			}
		}
	}

	# Now loop through and see if any player has 4 of a kind.
	# If they do, then assign these to discarded (-1)
	for {set i 0} {$i < [expr [llength $next_turn_cards] / 4]} {incr i} {
		set clubs $i
		set diamonds [expr $i + 13]
		set hearts [expr $i + 26]
		set spades [expr $i + 39]
		set players_with_kind [list [lindex $next_turn_cards $clubs] [lindex $next_turn_cards $diamonds] [lindex $next_turn_cards $hearts] [lindex $next_turn_cards $spades]]
		set players_with_kind [lsort -unique $players_with_kind]
		if {[llength $players_with_kind] == 1 && [lindex $players_with_kind 0] > 0} {
			# This player has 4 of a kind, so discard them
			lset next_turn_cards $clubs -1
			lset next_turn_cards $diamonds -1
			lset next_turn_cards $hearts -1
			lset next_turn_cards $spades -1
		}
	}

	set turn_no [incr previous_turn_no]
	set action "call cheat"

	# Now we can insert the turn into the databse
	set sql {
		insert into tTurn
			(game_id,
			user_id,
			turn_no,
			cards,
			action,
			kind)
		values
			(?,?,?,?,?,?)
	}

	if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
		tpBindString err_msg "error occured while preparing statement"
		ob::log::write ERROR {===>error: $msg}
		tpSetVar err 1
		asPlayFile -nocache training/cheat/cheat_main.html
		return
	}

	if {[catch {set rs [inf_exec_stmt $stmt $game_id $user_id $cards $turn_no $action $kind_played_last_turn]} msg]} {
		tpBindString err_msg "error occured while executing query"
		ob::log::write ERROR {===>error: $msg}
		catch {inf_close_stmt $stmt}
		tpSetVar err 1
		asPlayFile -nocache training/cheat/cheat_main.html
		return
	}

	catch {inf_close_stmt $stmt}

	# Now we can create all the info to pass back to the frontend

	# If the previous player cheated, then the current player gets
	# another turn. If not, then play moves on to the next player.
	set next_player_id 0

	if {cheat} {
		set next_player_id $user_id
	} else {
		set next_player_id [get_next_player $user_id]
	}

	create_json_response $game_id $next_turn_cards -1 $next_player_id $turn_no 1 0
}

proc get_next_player {current_player_id} {
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

	set statment [inf_prep_sql $DB $sql]
	set results [inf_exec_stmt $statement $game_id]
	inf_close_stmt $statement
		
	set game_players []

	for {set i 0} {$i < [db_get_nrows $results]} {incr i} {
		lappend game_players [db_get_col $results $i]
	}

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
	if {$next_player == 0} {
		set next_player_id [lindex $game_players 0]
	}

	return $next_player_id
}
}
