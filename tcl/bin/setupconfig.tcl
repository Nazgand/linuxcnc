#!/bin/sh
# this line restarts using wish \
exec wish "$0" "$@"

###############################################################
# Description:  setupconfig.tcl
#               This file, shows existing emc2 configuration
#               and allows copying and naming
#
#  Author: John Kasunich & Raymond E Henry
#  License: GPL Version 2
#
#  Copyright (c) 2005 All rights reserved.
#
#  Last change:
# $Revision$
# $Author$
# $Date$
###############################################################

################### PROCEDURE DEFINITIONS #####################

# reads the directory, and fills in "config_list" and "details_list"

proc get_config_list {} {
    global config_list details_list basedir

    # clear config and description lists
    set config_list [ list ]
    set details_list [ list ]
    # change to the configs directory
    cd $basedir
    # look at all subdirs
    foreach dir_name [ glob */ ] {
	cd $dir_name
	# is there an ini file (or more than one) inside?
	set inifnames [concat [ glob -nocomplain *.ini ]]
	if { [llength $inifnames]!= "0" } {
	    # yes, this is a viable config
	    # strip trailing / 
	    regsub "/" $dir_name "" config_name
	    # and save it
	    lappend config_list $config_name
	    # look for a README file
	    if { [ file isfile "README" ] } {
		# description found, read it
		set descr [ read -nonewline [ open "README" ]]
		# reformat - remove line breaks, preserve paragraph breaks
		regsub -all {([^\n])\n([^\n])} $descr {\1 \2} descr
		# and save it
		lappend details_list $descr
	    } else {
		# no description, gotta tell the user something
		lappend details_list "No details available."
	    }
	}
	# back to main configs directory
	cd ..
    }
}

# main button callback, it assigns the button name to 'choice'

proc button_pushed { button_name } {
    global choice

    set choice $button_name
}

# generic popup, displays a message and waits for "OK" click

proc popup { message } {
    global choice top

    set f1 [ frame $top.f1 ]
    set lbl [ label $f1.lbl -text $message -padx 20 -pady 10 ]
    set but [ button $f1.but -text OK -command "button_pushed OK" ]
    pack $lbl -side top
    pack $but -side bottom -padx 10 -pady 10
    pack $f1
    set choice "none"
    vwait choice
    pack forget $f1
    destroy $f1
}

# generic wizard page - defines a frame with multiple buttons at the bottom
# Returns the frame widget so page specific stuff can be packed on top

proc wizard_page { buttons } {
    global choice top

    set f1 [ frame $top.f1 ]
    set f2 [ frame $f1.f2 ]
    foreach button_name $buttons {
	set bname [ string tolower $button_name ]
        button $f2.$bname -text $button_name -command "button_pushed $button_name"
	pack $f2.$bname -side left -padx 10 -pady 10
    }
    pack $f2 -side bottom
    return $f1
}


# detail picker - lets you select from a list, displays details
# of the selected item

proc detail_picker { parent_wgt item_text item_list detail_text detail_list } {
    # need some globals to talk to our callback function
    global d_p_item_list d_p_item_widget d_p_detail_list d_p_detail_widget
    # and one for the result
    global detail_picker_selection

    # init the globals
    set d_p_item_list $item_list
    set d_p_detail_list $detail_list
    set detail_picker_selection ""

    # frame for the whole thing
    set f1 [ frame $parent_wgt.f1 ]
    
    # label for the item list
    set l1 [ label $f1.l1 -text $item_text ]
    pack $l1 -pady 6

    # subframe for the list and its scrollbar
    set f2 [ frame $f1.f2 ]

    # listbox for the items
    set lb [ listbox $f2.lb ]
    set d_p_item_widget $lb
    # pack the listbox into its subframe
    pack $lb -side left -fill y -expand y
    # hook up the callback to display the description
    bind $lb <<ListboxSelect>> detail_picker_refresh
    # load the list with names
    foreach item $item_list {
        $lb insert end $item
    }
    # if more than 'max' entries, use a scrollbar
    set max_items 6
    if { [ $lb size ] >= $max_items } {
	# need a scrollbar
	set lscr [ scrollbar $f2.scr -command "$lb yview" ]
	# set the listbox to the max height
	$lb configure -height $max_items
	# link it to the scrollbar
	$lb configure -yscrollcommand "$lscr set"
	# pack the scrollbar into the subframe
	pack $lscr -fill y -side right
    } else {
	# no scrollbar needed, make the box fit the list  (plus some 
	# space, so the user can tell that he is seeing the entire list)
	$lb configure -height [ expr { [ $lb size ] + 1 } ]
    }
    # pack the subframe into the main frame
    pack $f2

    # label for the details box
    set l2 [ label $f1.l2 -text $detail_text ]
    pack $l2 -pady 6
	
    # subframe for the detail box and its scrollbar
    set f3 [ frame $f1.f3 ]
    # a text box to display the details
    set tb [ text $f3.tb -width 60 -height 10 -wrap word -padx 6 -pady 6 \
             -relief sunken -takefocus 0 -state disabled ]
    set d_p_detail_widget $tb
    # pack the text box into its subframe
    pack $tb -side left -fill y -expand y
    # need a scrollbar
    set dscr [ scrollbar $f3.scr -command "$tb yview" ]
    # link the text box to the scrollbar
    $tb configure -yscrollcommand "$dscr set"
    # pack the scrollbar into the subframe
    pack $dscr -fill y -side right
    # pack the subframe into the main frame
    pack $f3
    # and finally pack the main frame into the parent
    pack $f1
}

# callback to display the details when the user selects different items
proc detail_picker_refresh {} {
    # need some globals from the main function
    global d_p_item_list d_p_item_widget d_p_detail_list d_p_detail_widget
    # and one for the result
    global detail_picker_selection

    # get ID of current selection
    set pick [ $d_p_item_widget curselection ]
    # save name of current selection
    set detail_picker_selection [ lindex $d_p_item_list $pick ]
    # get the details
    set detail [ lindex $d_p_detail_list $pick ]
    # enable changes to the details widget
    $d_p_detail_widget configure -state normal
    # jam the new text in there
    $d_p_detail_widget delete 1.0 end
    $d_p_detail_widget insert end $detail
    # lock it again
    $d_p_detail_widget configure -state disabled
}


proc choose_run_config {} {
    # need globals to comminicate with wizard page buttons,
    # and for the configuration lists
    global choice top wizard_state
    global config_list details_list detail_picker_selection
    # more globals for new and run config info
    global new_config_name new_config_template new_config_readme
    global run_config_name run_ini_name

    # messages
    set t1 "You did not specify an EMC configuration.\nPlease select one from the list below and click 'RUN',\nor click 'NEW' to create a new configuration."
    set t2 "\nDetails about the selected configuration:"
    
    #set up a wizard page with three buttons
    set f1 [ wizard_page { "NEW" "QUIT" " RUN " } ]
    # add a detail picker to it with the configs
    detail_picker $f1 $t1 $config_list $t2 $details_list
    # done
    pack $f1

    # prep for the event loop
    set choice "none"
    # enter event loop
    vwait choice
    # a button was pushed, save selection
    set value $detail_picker_selection
    # clear the window
    pack forget $f1
    destroy $f1

    switch $choice {
	"QUIT" {
	    set wizard_state "quit"
	    return
	}
	"RUN" {
	    if { $value == "" } {
		popup "You must choose a config if you want to run EMC2!"
		return
	    }
	    set run_config_name $value
	    set wizard_state "choose_run_ini"
	    return
	}
	"NEW" {
	    # get ready for a fresh start
	    set new_config_name ""
	    set new_config_template ""
	    set new_config_readme ""
	    set wizard_state "new_intro"
	    return
	}
    }
}

proc choose_run_ini {} {
    # need globals to comminicate with wizard page buttons
    global choice top wizard_state
    
    # not done yet
    popup "The next step is to see if there is more than one .ini fil in\nthe chosen config, and if so, to pick one.\n\nBut thats not coded yet, so when you click OK, the program will end"
    set wizard_state "quit"
    return
}

proc new_intro {} {
    # need globals to comminicate with wizard page buttons
    global choice top wizard_state

    set f1 [ wizard_page { "<--BACK" "QUIT" "NEXT-->" } ]
    set l1 [ label $f1.l1 -text "You have chosen to create a new EMC2 configuration.\n\nThe next few screens will walk you through the process." ]
    pack $l1 -padx 10 -pady 10
    pack $f1

    set choice "none"
    vwait choice
    pack forget $f1
    destroy $f1

    switch $choice {
	"QUIT" {
	    set wizard_state "quit"
	    return
	}
	"<--BACK" {
	    set wizard_state "choose_run_config"
	    return
	}
	"NEXT-->" {
	    set wizard_state "new_get_name"
	    return
	}
    }
}    

proc new_get_name {} {
    # need globals to comminicate with wizard page buttons
    global choice top wizard_state new_config_name

    set f1 [ wizard_page { "<--BACK" "QUIT" "NEXT-->" } ]
    set l1 [ label $f1.l1 -text "Please select a name for your new configuration." ]
    set l2 [ label $f1.l2 -text "(This will become a directory name, so please use only letters,\ndigits, period, dash, or underscore.)" ]
    set e1 [ entry $f1.e1 -width 30 -relief sunken -bg white -takefocus 1 ]
    $e1 insert 0 $new_config_name
    pack $l1 -padx 10 -pady 10
    pack $e1 -padx 10 -pady 1
    pack $l2 -padx 10 -pady 10
    pack $f1

    set choice "none"
    vwait choice
    set value [ $e1 get ]
    pack forget $f1
    destroy $f1

    switch $choice {
	"QUIT" {
	    set wizard_state "quit"
	    return
	}
	"<--BACK" {
	    set wizard_state "new_intro"
	    return
	}
	"NEXT-->" {
	    if { $value == "" } {
		popup "You must enter a name!"
		return
	    }
	    if { [ regexp {[^[:alnum:]_\-.]} $value ] == 1 } {
		popup "'$value' contains illegal characters!\nPlease choose a new name."
		return
	    }
	    if { [ file exists $value ] == 1 } {
		popup "A directory or file called '$value' already exists!\nPlease choose a new name."
		return
	    }
	    set new_config_name $value
	    set wizard_state "new_get_template"
	    return
	}
    }
}    
    
proc new_get_template {} {
    # need globals to comminicate with wizard page buttons,
    # and for the configuration lists
    global choice top wizard_state
    global config_list details_list detail_picker_selection
    global new_config_name new_config_template new_config_readme

    # messages
    set t1 "Please select one of these existing configurations as the template\nfor your new configuration.\n\nAll the files associated with the template will be copied into your new\nconfig, so you can make whatever modifications are needed."
    set t2 "\nDetails about the selected configuration:"
    
    #set up a wizard page with three buttons
    set f1 [ wizard_page { "<--BACK" "QUIT" "NEXT-->" } ]
    # add a header line
    set l1 [ label $f1.l1 -text "Creating new EMC2 configuration '$new_config_name'" ]
    pack $l1 -pady 10
    # add a detail picker to it with the configs
    detail_picker $f1 $t1 $config_list $t2 $details_list
    # done
    pack $f1

    set choice "none"
    vwait choice
    set value $detail_picker_selection
    pack forget $f1
    destroy $f1

    switch $choice {
	"QUIT" {
	    set wizard_state "quit"
	    return
	}
	"<--BACK" {
	    set wizard_state "new_get_name"
	    return
	}
	"NEXT-->" {
	    if { $value == "" } {
		popup "You must choose a template!"
		return
	    }
	    if { [ file isdirectory $value ] != 1 } {
		popup "A internal error has occurred, or the template directory was deleted.\nClick OK to quit"
		set wizard_state "quit"
		return
	    }
	    set new_config_template $value
	    # look up the details that match this template
	    # NOTE: we do this here, instead of at the beginning of "new_get_description"
	    #  so that anything the user has typed survives if he goes back to the new
	    #  description page.  His data is only overwritten by the template if he
	    #  goes all the way back to the template slection page (this one).
	    if { [ file isfile "$new_config_template/README" ] } {
		# description found, read it
		set descr [ read -nonewline [ open "$new_config_template/README" ]]
		# and save it
		set new_config_readme $descr
	    } else {
		# no description, gotta tell the user something
		set new_config_readme "Enter a description here"
	    }
	    set wizard_state "new_get_description"
	    return
	}
    }
}

proc new_get_description {} {
    # need globals to comminicate with wizard page buttons
    global choice top wizard_state 
    global new_config_name new_config_template new_config_readme

    set f1 [ wizard_page { "<--BACK" "QUIT" "NEXT-->" } ]
    # add a header line
    set l1 [ label $f1.l1 -text "Creating new EMC2 configuration '$new_config_name'\nbased on template '$new_config_template'" ]
    pack $l1 -pady 10
    set l2 [ label $f1.l2 -text "Please enter a description of your configuration.\n\nThe box below has been preloaded with the description of the template, but\nit is strongly recommended that you revise it.  At a minimum,\nput your name and some specifics about your machine here." ]
    set l3 [ label $f1.l3 -text "(If you ever need help, someone may ask you to send them your\nconfiguration, and this information could be very usefull.)" ]

    # subframe for the text entry box and its scrollbar
    set f3 [ frame $f1.f3 ]
    #  text box
    set tb [ text $f3.tb -width 60 -height 10 -wrap word -padx 6 -pady 6 \
             -relief sunken -takefocus 1 -state normal -bg white ]
    $tb insert end $new_config_readme
    # pack the text box into its subframe
    pack $tb -side left -fill y -expand y
    # need a scrollbar
    set scr [ scrollbar $f3.sc -command "$tb yview" ]
    # link the text box to the scrollbar
    $tb configure -yscrollcommand "$scr set"
    # pack the scrollbar into the subframe
    pack $scr -fill y -side right
  
    # pack things into the main frame    
    pack $l1 -padx 10 -pady 10
    pack $l2 -padx 10 -pady 10
    pack $f3 -padx 10 -pady 1
    pack $l3 -padx 10 -pady 10
    pack $f1

    set choice "none"
    vwait choice
    set value [ $tb get 1.0 end ]
    pack forget $f1
    destroy $f1

    switch $choice {
	"QUIT" {
	    set wizard_state "quit"
	    return
	}
	"<--BACK" {
	    set wizard_state "new_get_template"
	    return
	}
	"NEXT-->" {
	    if { $value == "\n" } {
		popup "You must enter at least one word!"
		return
	    }
	    set new_config_readme $value
	    set wizard_state "new_verify"
	    return
	}
    }
}    

proc new_verify {} {
    # need globals to comminicate with wizard page buttons
    global choice top wizard_state 
    global new_config_name new_config_template new_config_readme

    set f1 [ wizard_page { "<--BACK" "QUIT" "NEXT-->" } ]
    # add a header line
    set l1 [ label $f1.l1 -text "You are about to create a new EMC2 configuration.\n\nPlease verify that this is what you want:\n\nName '$new_config_name'\nTemplate: '$new_config_template'\nDescription:" ]
    pack $l1 -pady 10
    set l2 [ label $f1.l2 -text "If this information is correct, click NEXT to create\nthe configuration directory and begin copying files." ]

    # subframe for the text box and its scrollbar
    set f3 [ frame $f1.f3 ]
    #  text box
    set tb [ text $f3.tb -width 60 -height 10 -wrap word -padx 6 -pady 6 \
             -relief sunken -takefocus 1 -state normal ]
    $tb insert end $new_config_readme
    $tb configure -state disabled
    # pack the text box into its subframe
    pack $tb -side left -fill y -expand y
    # need a scrollbar
    set scr [ scrollbar $f3.sc -command "$tb yview" ]
    # link the text box to the scrollbar
    $tb configure -yscrollcommand "$scr set"
    # pack the scrollbar into the subframe
    pack $scr -fill y -side right
  
    # pack things into the main frame    
    pack $l1 -padx 10 -pady 10
    pack $f3 -padx 10 -pady 1
    pack $l2 -padx 10 -pady 10
    pack $f1

    set choice "none"
    vwait choice
    pack forget $f1
    destroy $f1

    switch $choice {
	"QUIT" {
	    set wizard_state "quit"
	    return
	}
	"<--BACK" {
	    set wizard_state "new_get_description"
	    return
	}
	"NEXT-->" {
	    set wizard_state "new_do_copying"
	    return
	}
    }
}    

proc new_do_copying {} {
    # need globals to communicate with wizard page buttons
    global choice top wizard_state
    
    # not done yet
    popup "The next step is to start copying files.\n\nBut thats not coded yet, so when you click OK, the program will end"
    set wizard_state "quit"
    return
}


################ MAIN PROGRAM STARTS HERE ####################


proc state_machine {} {
    global choice wizard_state

    set wizard_state "choose_run_config"
    while { $wizard_state != "quit" } {
	puts "state is $wizard_state"
	# execute the code associated with the current state
	$wizard_state
    }
}

# set options that are common to all widgets
foreach class { Button Entry Label Listbox Scale Text } {
    option add *$class.borderWidth 1  100
}

# locate the configs directory
set basedir ""
if {[info exists env(EMC2_ORIG_CONFIG_DIR)]} {
    set basedir $env(EMC2_ORIG_CONFIG_DIR)
}
if {$basedir == ""} {
    # maybe we're running in the top level EMC2 dir
    if { [ file isdirectory "configs" ] } {
	set basedir configs/
    }
}
if {$basedir == ""} {
    # maybe we're running in the configs dir or another at that level
    if { [ file isdirectory "../configs" ] } {
	set basedir ../configs
    }
}
if {$basedir == ""} {
    # maybe we're running in an inidividual config dir
    if { [ file isdirectory "../../configs" ] } {
	set basedir ../
    }
}
if {$basedir == ""} {
    # give up
    puts "Can't find configs directory"
    puts "Check environment variable EMC2_ORIG_CONFIG_DIR"
    exit -1
}

# read the directory and set up lists
get_config_list

# make a toplevel and a master frame.
wm title . "EMC2 Configuration Manager"
set top [frame .main -borderwidth 2 -relief raised ]
# want these too, but on windoze they cause an error? -padx 10 -pady 10 ]
pack $top -expand yes -fill both

# initialize a bunch of globals
set run_config_name ""
set run_ini_name ""


state_machine
puts Quitting!
exit


