# dialog:
# dialog --title "Some Title" --menu --stdout <width?0=auto> <height?0=auto> <num choices> [k, v]

my ($device_id_file, $controller_mapping_file) = @ARGV;

unless (defined $device_id_file) {
	$device_id_file = "/etc/emulationstation/es_input.cfg";
}

unless (defined $controller_mapping_file) {
	# ./tools/PortMaster/batocera/gamecontrollerdb.txt
	# ./tools/PortMaster/knulli/gamecontrollerdb.txt
	# ./tools/PortMaster/gamecontrollerdb.txt
	$controller_mapping_file = "/roms/tools/PortMaster/gamecontrollerdb.txt";
}

my $device_id = get_device_id($device_id_file);

my (
	$device_name,
	$controller_config_order,
	$controller_config_hotkeys
) = get_controller_config($controller_mapping_file, $device_id);

# To avoid reaching for something like an index map we just keep track
# of the insertion order of the hotkeys into the map manually
my @order = @$controller_config_order;
my %hotkeys = %$controller_config_hotkeys;
my @relevant_keys = grep(/leftx|lefty|rightx|righty|leftstick|rightstick/, @order);

while($item = draw_main_menu(\@relevant_keys, \%hotkeys)) {
	if ($item eq "a") {
		%hotkeys = swap_keys("leftx", "rightx", %hotkeys);
		%hotkeys = swap_keys("lefty", "righty", %hotkeys);
	} elsif ($item eq "b") {
		%hotkeys = swap_keys("leftstick", "rightstick", %hotkeys);
	} elsif ($item eq "c") {
		%hotkeys = swap_keys("leftx", "lefty", %hotkeys);
	} elsif ($item eq "d") {
		%hotkeys = swap_keys("rightx", "righty", %hotkeys);
	} elsif ($item eq "e") {
		%hotkeys = invert_key("leftx", %hotkeys);
	} elsif ($item eq "f") {
		%hotkeys = invert_key("lefty", %hotkeys);
	} elsif ($item eq "g") {
		%hotkeys = invert_key("rightx", %hotkeys);
	} elsif ($item eq "h") {
		%hotkeys = invert_key("righty", %hotkeys);
	} elsif ($item eq "i") {
		last;
	}
};

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
	open(my $fh, "<", $input_path) or die "$!";
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
		return ($device_name, \@order, \%hotkeys);
	}
	return (undef, undef, undef);
}

sub print_hotkeys {
	my ($relevant_keys, $hotkeys) = @_;
	my %hotkeys = %$hotkeys;
	my @relevant_keys = @$relevant_keys;

	my $acc = "";
	foreach my $key (@relevant_keys) {
		$acc .= "$key: $hotkeys{$key}\n";
	}
	return $acc
}

# UI
sub draw_main_menu {
	my ($relevant_keys, $hotkeys) = @_;
	my %hotkeys = %$hotkeys;
	my @relevant_keys = @$relevant_keys;
	my $current_bindings = print_hotkeys(\@relevant_keys, \%hotkeys);
	# Really janky workaround for having to get data out of command, we can't use
	# backticks in the command to capture output, because the device isn't allowing
	# the dialog to spawn, and the alternative is managing the menu in bash, which 
	# to be fair might actually be a better approach.
	my $temp_file = "/tmp/menu_choice";

	system("dialog " . 
		"--backtitle \"Analog Stick Inverter by Gerhardus\" " .
		"--title \"Analog Stick Inverter\" " .
		"--no-collapse " .
		"--clear " .
		"--menu \"$current_bindings\" " .
		# WIDTH HEIGHT NUM OPTIONS
		"0 0 9 " .
		# OPTIONS
		"a \"BOTH:    SWAP\" " .
		"b \"BOTH:    SWAP BTNS\" " .
		"c \"LEFT:    ROTATE\" " .
		"d \"RIGHT:   ROTATE\" " .
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

# my $main_menu_choice = draw_main_menu();
# print "\n$main_menu_choice\n";


