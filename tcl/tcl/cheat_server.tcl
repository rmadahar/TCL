namespace eval CHEAT {

        asSetAct CHEAT_four_players       [namespace code four_players]

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
	catch {db_close $rs}

	tpSetVar     num_players  $players
	if {$players >= 4} {
        	tpBindString start_game   "The game is started"
	}
	asPlayFile -nocache cheat/cheat_main.html
}

}

