#!/bin/perl

use XML::Twig;

# /roms/tools/inverter
my ($device_id_file, $workdir) = @ARGV;

unless (defined $device_id_file) {
	$device_id_file = "/etc/emulationstation/es_input.cfg";
}

unless (defined $workdir) {
	$workdir = "/roms/tools/inverter"
}

main($device_id_file, $workdir);

sub main {
	my ($device_id_file, $workdir) = @_;
	my $controller_file_list_file_name = "controller_file_list.txt";
	my $backup_file = "$workdir/$controller_file_list_file_name";

	unless (-e $backup_file) {
		refresh_backup_file($backup_file);
	}

	# Check existing controller files
	while(my $choice = draw_main_menu()) {
		if($choice eq "a"){
			my $controller_mapping_file = draw_select_controller_file($backup_file);
			next unless($controller_mapping_file);
			chomp $controller_mapping_file;
			handle_txt_input_file($device_id_file, $controller_mapping_file);
		} elsif($choice eq "b") {
			handle_xml_input_file($device_id_file);
		} elsif($choice eq "c") {
			refresh_backup_file($backup_file);
		};
	}
}

sub refresh_backup_file {
	my ($backup_file) = @_;
	system("find / -name gamecontrollerdb.txt 2>/dev/null | tee $backup_file | dialog --backtitle \"Analog Stick Inverter by Gerhardus\" --progressbox 0 0");
	open(my $fh, "<", $backup_file);
	my @files = <$fh>;
	close($fh);
}

sub draw_select_controller_file {
	my ($backup_file) = @_;

	open(my $fh, "<", $backup_file) or system("dialog --backtitle \"Analog Stick Inverter by Gerhardus\" --msgbox \"Something went wrong\"");
	my @files = <$fh>;
	close($fh);
	my $length = @files;

	my $temp_file_name = "/tmp/tempcontrollerfileselection";
	my $description = "Select a file";

	my %files;
	my $char = 'a';
	my $command = "dialog " .
		"--backtitle \"Analog Stick Inverter by Gerhardus\" " .
		"--cancel-label BACK " .
		"--menu \"$description\" 0 0 $length ";

	foreach $file (@files) {
		$files{$char} = $file;
		$command .= "$char ";
		$command .= "\"$file\" ";
		$char++;
	}
	$command .= "2> $temp_file_name";

	system($command);
	open(my $tfh, "<", $temp_file_name) or return undef;
	my $choice = <$tfh>;
	close($tfh);
	unlink($temp_file_name);

	return $files{$choice};
}


# MENU 1: Options:
# 1. Emulationstation (only /etc/emulationstation/es_input.cfg)
# 2. Other
# 3. Scan for controls files (refresh)
sub draw_main_menu {
	my $tempfilename = "/tmp/tempmainmenuchoice";
	my $description = "Choose which analog sticks to invert.\
Emulationstation is the main menu, while
Games is related to games.
Emulationstation -> es_input.cfg
Games            -> gamecontrollerdb.txt";

	system("dialog " . 
		"--backtitle \"Analog Stick Inverter by Gerhardus\" " .
		# "--default-item $last_choice " .
		"--title \"Analog Stick Inverter\" " .
		"--cancel-label EXIT " .
		"--no-collapse " .
		"--clear " .
		"--menu \"$description\" " .
		# WIDTH HEIGHT NUM OPTIONS
		"0 0 3 " .
		# OPTIONS
		"a \"PLATFORMS ETC\" " .
		"b \"EMULATIONSTATION\" " .
		"c \"REFRESH GAMES LIST\" " .
		"2> $tempfilename"
	);

	my $temp_file = open(my $fh, "<", $tempfilename) or return undef;
	my $choice = <$fh>;
	close($fh);
	unlink($temp_file);
	return $choice;
}

sub handle_txt_input_file {
	my ($device_id_file, $controller_mapping_file) = @_;

	my $device_id = get_device_id($device_id_file);

	my (
		$device_name,
		$controller_config_order,
		$controller_config_hotkeys,
		$old_full_config_line,
	) = get_controller_config($controller_mapping_file, $device_id);

	# To avoid reaching for something like an index map we just keep track
	# of the insertion order of the hotkeys into the map manually
	my @order = @$controller_config_order;
	my %hotkeys = %$controller_config_hotkeys;
	my @relevant_keys = grep(/(:?left|right)(?:x|y|stick)/, @order);

	my $last_choice = "a";
	while($item = draw_controller_menu(\@relevant_keys, \%hotkeys, $last_choice, "GAME")) {
		$last_choice = $item;
		# "a \"BOTH:    SWAP\" " .
		if ($item eq "a") {
			%hotkeys = swap_keys("leftx", "rightx", %hotkeys);
			%hotkeys = swap_keys("lefty", "righty", %hotkeys);
		# "b \"BOTH:    SWAP TRIGGERS\" " .
		} elsif ($item eq "b") {
			%hotkeys = swap_keys("leftstick", "rightstick", %hotkeys);
		# "c \"LEFT:    SWAP AXES\" " .
		} elsif ($item eq "c") {
			%hotkeys = swap_keys("leftx", "lefty", %hotkeys);
		# "d \"RIGHT:   SWAP AXES\" " .
		} elsif ($item eq "d") {
			%hotkeys = swap_keys("rightx", "righty", %hotkeys);
		# "e \"LEFT_X:  INVERT\" " .
		} elsif ($item eq "e") {
			%hotkeys = invert_key("leftx", %hotkeys);
		# "f \"LEFT_Y:  INVERT\" " .
		} elsif ($item eq "f") {
			%hotkeys = invert_key("lefty", %hotkeys);
		# "g \"RIGHT_X: INVERT\" " .
		} elsif ($item eq "g") {
			%hotkeys = invert_key("rightx", %hotkeys);
		# "h \"RIGHT_Y: INVERT\" " .
		} elsif ($item eq "h") {
		# "i \"SAVE AND EXIT\" " .
			%hotkeys = invert_key("righty", %hotkeys);
		} elsif ($item eq "i") {
			my $reformed_line = reform_line($device_id, $device_name, \@order, \%hotkeys);
			last if ($old_full_config_line eq $reformed_line);

			open(my $cm_file, "<", "$controller_mapping_file") or die "Could read controller file";
			open(my $temp_file, ">", "$controller_mapping_file.tmp") or die "Could not create temp file";

			while($line = <$cm_file>) {
				if ($line =~ /^$device_id/) {
					print $temp_file $reformed_line;
				} else {
					print $temp_file $line;
				}
			};

			close($cm_file);
			close($temp_file);
			unless (-z "$controller_mapping_file.tmp") {
				rename("$controller_mapping_file.tmp", $controller_mapping_file);
				system("dialog --title \"FINISHED\" " .
					"--backtitle \"Analog Stick Inverter by Gerhardus\" " .
					"--msgbox " .
					"\"Sucessfully updated config file\" " .
					"0 0");
			}
			last;
		}
	};

}


# UTILS
sub reform_line {
	my ($device_id, $device_name, $order, $hotkeys) = @_;

	my @order = @$order;
	my %hotkeys = %$hotkeys;

	my $output = "$device_id,$device_name,";

	foreach my $key (@order) {
		$output .= "$key:$hotkeys{$key},";
	}
	return "$output\n";
}

# Key 1, Key 2, Map reference
sub swap_keys {
	my ($key1, $key2, %hotkeys) = @_;
	
	my $temp = $hotkeys{$key1};
	$hotkeys{$key1} = $hotkeys{$key2};
	$hotkeys{$key2} = $temp;
	
	return %hotkeys;
}

sub invert_key {
	my ($key, %hotkeys) = @_;
	
	if ($hotkeys{$key} =~ /(.+)~$/) {
		$hotkeys{$key} = $1;
	} elsif ($hotkeys{$key} =~ /(.+[^~])$/) {
		$hotkeys{$key} = "$1~";
	};

	return %hotkeys;
}

# DATA SOURCES
sub get_device_id {
	my ($input_path) = @_;
	open(my $fh, "<", $input_path) or return undef;
	my $device_id;

	while (my $line = <$fh>) {
		if ($line =~ /deviceGUID=["']([a-zA-Z0-9]+)["']/) {
			my $match = $1;
			return $match;
		}
	};
	close($fh);
	return undef;
}

sub get_controller_config {
	my ($mapping_file, $input_device_id) = @_;
	open(my $fh, "<", $mapping_file) or return undef;

	while (my $line = <$fh>) {
		next if($line =~ /^[#\s]/);

		my ($device_id, $device_name, @inputs) = split(/,/, $line);
		next if($device_id ne $input_device_id);

		my %hotkeys;
		my @order;

		foreach my $item (@inputs) {
			my ($k, $v) = split /:/, $item;
			if (defined $k && defined $v) {
				push @order, $k;
				$hotkeys{$k} = $v;
			}
		}
		return ($device_name, \@order, \%hotkeys, $line);
	}
	return (undef, undef, undef, undef);
}

sub print_hotkeys {
	my ($relevant_keys, $hotkeys) = @_;
	my %hotkeys = %$hotkeys;
	my @relevant_keys = @$relevant_keys;

	my @left_keys = grep(/^l/, @relevant_keys);
	my @right_keys = grep(/^r/, @relevant_keys);

	my $length = @left_keys;

	my $acc = "";
	for (my $i = 0; $i < $length; $i++) {
		my $key = $left_keys[$i];
		my $display_key = to_constant_length_string($key, 10);
		my $display_val = to_constant_length_string($hotkeys{$key}, 4);
		$acc .= "$display_key: $display_val | ";

		$key = $right_keys[$i];
		$display_key = to_constant_length_string($key, 10);
		$display_val = to_constant_length_string($hotkeys{$key}, 4);
		$acc .= "$display_key: $display_val\n";
	}
	return $acc
}

# UI
sub draw_controller_menu {
	my ($relevant_keys, $hotkeys, $last_choice, $type) = @_;
	my %hotkeys = %$hotkeys;
	my @relevant_keys = @$relevant_keys;

	my $current_bindings = "";
	if ($type eq "GAME") {
		$current_bindings = print_hotkeys(\@relevant_keys, \%hotkeys);
	} else {
		$current_bindings = print_xml_hotkeys(\@relevant_keys, \%hotkeys);
	}
	# Really janky workaround for having to get data out of command, we can't use
	# backticks in the command to capture output, because the device isn't allowing
	# the dialog to spawn, and the alternative is managing the menu in bash
	my $temp_file = "/tmp/menu_choice";

	system("dialog " . 
		"--backtitle \"Analog Stick Inverter by Gerhardus\" " .
		"--default-item $last_choice " .
		"--cancel-label BACK " .
		"--title \"Invert analog sticks for $type\" " .
		"--no-collapse " .
		"--clear " .
		"--menu \"$current_bindings\" " .
		# WIDTH HEIGHT NUM OPTIONS
		"0 0 9 " .
		# OPTIONS
		"a \"BOTH:    SWAP\" " .
		"b \"BOTH:    SWAP TRIGGERS\" " .
		"c \"LEFT:    SWAP AXES\" " .
		"d \"RIGHT:   SWAP AXES\" " .
		"e \"LEFT_X:  INVERT\" " .
		"f \"LEFT_Y:  INVERT\" " .
		"g \"RIGHT_X: INVERT\" " .
		"h \"RIGHT_Y: INVERT\" " .
		"i \"SAVE AND EXIT\" " .
		"2> $temp_file"
	);

	open(my $fh, '<', $temp_file) or return undef;
	my $choice = <$fh>;
	close($fh);
	unlink($temp_file);
	return $choice;
}

# NOTE: XML HANDLING
sub handle_xml_input_file {
	my ($file_name) = @_;

	my $twig = XML::Twig->new(
		keep_spaces      => 1,
		keep_atts_order  => 1,
		keep_encoding    => 1,
		comments         => 'keep',
		pi               => 'keep',
	);
	$twig->parsefile($file_name);

	my @nodes = $twig->find_nodes('*/input[@name]');

	my %hotkeys = get_current_xml_hotkeys(\@nodes);
	my @keys = keys %hotkeys;
	my @relevant_keys = grep(/(left|right)(analog(left|right|up|down)|trigger)/, @keys);

	my $last_choice = "a";

	while($item = draw_controller_menu(\@relevant_keys, \%hotkeys, $last_choice, "SYSTEM")) {
		$last_choice = $item;
		# "a \"BOTH:    SWAP\" " .
		if ($item eq "a") {
			# To swap sticks swap IDs of LEFT{LEFT,RIGHT,UP,DOWN}->RIGHT{LEFT,RIGHT,UP,DOWN}
			%hotkeys = swap_input_ids("leftanalogleft", "rightanalogleft", \%hotkeys);
			%hotkeys = swap_input_ids("leftanalogright", "rightanalogright", \%hotkeys);
			%hotkeys = swap_input_ids("leftanalogup", "rightanalogup", \%hotkeys);
			%hotkeys = swap_input_ids("leftanalogdown", "rightanalogdown", \%hotkeys);

		# "b \"BOTH:    SWAP TRIGGERS\" " .
		} elsif ($item eq "b") {
			# Just swap trigger ids
			%hotkeys = swap_input_ids("lefttrigger", "righttrigger", \%hotkeys);

		# "c \"LEFT:    SWAP AXES\" " .
		} elsif ($item eq "c") {
			# To rotate sticks swap ids of LEFT{LEFT,UP}->LEFT{RIGHT,DOWN}
			# ALIAS: ROTATE LEFT
			%hotkeys = swap_input_ids("leftanalogleft", "leftanalogup", \%hotkeys);
			%hotkeys = swap_input_ids("leftanalogright", "leftanalogdown", \%hotkeys);

		# "d \"RIGHT:   SWAP AXES\" " .
		} elsif ($item eq "d") {
			# To rotate sticks swap ids of RIGHT{LEFT,UP}->RIGHT{RIGHT,DOWN}
			# ALIAS: ROTATE RIGHT
			%hotkeys = swap_input_ids("rightanalogleft", "rightanalogup", \%hotkeys);
			%hotkeys = swap_input_ids("rightanalogright", "rightanalogdown", \%hotkeys);

		# "e \"LEFT_X:  INVERT\" " .
		} elsif ($item eq "e") {
			# The values are either 1 or -1 for type of "axis" and normally across
			# each axis they are opposite.
			# E.G. looking at left analog: left = -1 and right = 1
			%hotkeys = swap_input_values("leftanalogleft", "leftanalogright", \%hotkeys);

		# "f \"LEFT_Y:  INVERT\" " .
		} elsif ($item eq "f") {
			%hotkeys = swap_input_values("leftanalogdown", "leftanalogup", \%hotkeys);

		# "g \"RIGHT_X: INVERT\" " .
		} elsif ($item eq "g") {
			%hotkeys = swap_input_values("rightanalogleft", "rightanalogright", \%hotkeys);

		# "h \"RIGHT_Y: INVERT\" " .
		} elsif ($item eq "h") {
			%hotkeys = swap_input_values("rightanalogdown", "rightanalogup", \%hotkeys);

		# "i \"SAVE AND EXIT\" " .
		} elsif ($item eq "i") {

			set_new_xml_hotkeys(\@nodes, \%hotkeys);

			open(my $fh, ">", "$file_name.tmp") or die "$!";
			$twig->flush($fh);
			close($fh);

			unless (-z "$file_name.tmp") {
				rename("$file_name.tmp", $file_name);
				system("dialog --title \"FINISHED\" " .
					"--backtitle \"Analog Stick Inverter by Gerhardus\" " .
					"--msgbox " .
					"\"Sucessfully updated config file\" " .
					"10 30");
			}

			last;
		}
	};
}

# AFAIK the following is how to manipulate file:

sub swap_input_ids {
	my ($key1, $key2, $hotkeys) = @_;
	my %hotkeys = %$hotkeys;

	my $temp = @{$hotkeys{$key1}}[0];
	@{$hotkeys{$key1}}[0] = @{$hotkeys{$key2}}[0];
	@{$hotkeys{$key2}}[0] = $temp;

	return %hotkeys;
}

sub swap_input_values {
	my ($key1, $key2, $hotkeys) = @_;
	my %hotkeys = %$hotkeys;

	my $temp = @{$hotkeys{$key1}}[1];
	@{$hotkeys{$key1}}[1] = @{$hotkeys{$key2}}[1];
	@{$hotkeys{$key2}}[1] = $temp;

	return %hotkeys;

}

sub set_new_xml_hotkeys {
	my ($nodes, $hotkeys) = @_;

	my @nodes = @$nodes;

	my %hotkeys = %$hotkeys;

	foreach my $node (@nodes) {
		my $name = $node->att('name');

		my ($id, $value) = @{$hotkeys{$name}};
		$node->set_att('id', $id);
		$node->set_att('value', $value);
	}
}

# Hotkeys shape:
# { 'key_name': ['key_id', 'key_value'] }
sub get_current_xml_hotkeys{
	my ($nodes) = @_;
	my @nodes = @$nodes;

	my %hotkeys;

	foreach my $item (@nodes) {
		my $id = $item->att('id');
		my $name = $item->att('name');
		my $value = $item->att('value');

		
		$hotkeys{$name} = [$id, $value];
	};
	return %hotkeys;
}

sub print_xml_hotkeys {
	my ($relevant_keys, $hotkeys) = @_;
	my %hotkeys = %$hotkeys;
	my @relevant_keys = @$relevant_keys;

	my @left_keys = grep(/^left/, sort @relevant_keys);
	my @right_keys = grep(/^right/, sort @relevant_keys);

	my $length = @left_keys;

	my $acc = "";
	for (my $i = 0; $i < $length; $i++) {
		my $key = $left_keys[$i];
		my $display_key = to_constant_length_string($key, 15);
		my $display_id = $hotkeys{$key}[0];
		my $display_val = to_constant_length_string($hotkeys{$key}[1], 2);
		$acc .= "$display_key -> ID: $display_id, VAL: $display_val | ";

		$key = $right_keys[$i];
		$display_key = to_constant_length_string($key, 15);
		$display_id = $hotkeys{$key}[0];
		$display_val = to_constant_length_string($hotkeys{$key}[1], 2);
		$acc .= "$display_key -> ID: $display_id, VAL: $display_val\n";
	};

	return $acc
}

sub to_constant_length_string {
    my ($str, $len) = @_;

    if (length($str) >= $len) {
        return substr($str, 0, $len);
    }

    return $str . (" " x ($len - length($str)));
}

