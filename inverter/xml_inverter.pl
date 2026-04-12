#!/bin/perl

use XML::Twig;

my ($file_name) = @ARGV;

unless (defined $file_name) {
	$file_name = "/etc/emulationstation/es_input.cfg";
}

handle_xml_input_file($file_name);

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

	while($item = draw_controller_menu(\@relevant_keys, \%hotkeys, $last_choice)) {
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
			rename("$file_name.tmp", $file_name);

			system("dialog --title \"FINISHED\" " .
				"--msgbox " .
				"\"Sucessfully updated config file\" " .
				"10 30");
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

sub draw_controller_menu {
	my ($relevant_keys, $hotkeys, $last_choice) = @_;
	my %hotkeys = %$hotkeys;
	my @relevant_keys = @$relevant_keys;
	my $current_bindings = print_xml_hotkeys(\@relevant_keys, \%hotkeys);
	# Really janky workaround for having to get data out of command, we can't use
	# backticks in the command to capture output, because the device isn't allowing
	# the dialog to spawn, and the alternative is managing the menu in bash
	my $temp_file = "/tmp/menu_choice";

	system("dialog " . 
		"--backtitle \"Analog Stick Inverter by Gerhardus\" " .
		"--default-item $last_choice " .
		"--title \"Analog Stick Inverter\" " .
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
