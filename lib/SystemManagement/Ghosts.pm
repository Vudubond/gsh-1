package SystemManagement::Ghosts;
use warnings;
use strict;

use Exporter 'import';

our @EXPORT_OK = qw( Load Expanded UserConfig );

my $GHOSTS_PATH="/etc/ghosts";
my @GHOSTS_USER = ('$HOME/.ghosts', '$HOME/.config/ghosts', '$HOME/etc/ghosts');
my @GHOSTS;    # all the lines of the ghosts file

# loads the ghosts file into @sysadmin_ghosts
sub Load {
	my($file) = @_;
	my($line);
	$file=$GHOSTS_PATH if (!$file || $file eq "");
	open(GHOSTS_FILE,"<${file}") ||
		return;		# don't worry if file is unreadable
	while (<GHOSTS_FILE>) {
		# kill blank lines
		s/[ \t]*\n//;
		my $line = $_;
		# kill commented or blank lines
		if ($line ne "" && $line !~ /^#/) {
			push(@GHOSTS,$line);
		}
	}
	close(GHOSTS_FILE);
}

sub CheckGhostFor {
	my($machine,$what) = @_;
	my(@result,$list);

	@result=ParseGhosts(0,$what);
	$list=":".join(":",@result).":";

#	print "$what ($machine) sees $list\n";

	return 1 if ($list =~ /:$machine:/);
	return 0;
}

sub ParseGhosts {
	my($depth,@what) = @_;

	if ($depth>10) {
		print STDERR "ParseGhosts: recurrsive macro?  Depth == 10 at '".join(',',@what)."'\n";
		return ("");
	}

	# if no argument, match all machine names
	@what = ("all") if (!@what);

	# make the starting matching string, ":" separated
	my $one_of_these = ":" . join("+",@what) . ":";     # prepare to expand "macros"
	$one_of_these =~ s/\+/:/g;           # we hope to end up with list of
	$one_of_these =~ s/\^/:^/g;           #  colon separated attributes
	$one_of_these =~ s/:+/:/g;

#	warn "ParseGhosts[$depth]: expanding '$one_of_these'\n";
	my @repl;
	Load() if ($#GHOSTS<0);
	foreach my $line (@GHOSTS) {           # for each line of ghosts
		if ($line =~ /^(\w+)=(.+)/) {         # a macro line?
        		my $name = $1;
                my $repl = $2;
        		$repl =~ s/\+/:/g;	# make an addition
		        $repl =~ s/\^/:^/g;	# subtract
    			# do expansion in "wanted" list
        		if ($one_of_these =~ /:$name:/) {
				my @query = ParseGhosts($depth+1,$repl);
				$repl = ":" . join(":",@query) . ":";
#				warn "'$one_of_these' matched '$name' as '$repl'\n";
        			$one_of_these =~ s/:$name:/:$repl:/;
			}

			# do expansion in "unwanted" list
        		if ($one_of_these =~ /:-$name:/) {
				my @query = ParseGhosts($depth+1,$repl);
				$repl = ":" . join(":",@query) . ":";
			        $repl =~ s/:/:^/g;
#				warn "'$one_of_these' matched '-$name' as '$repl'\n";
		        	$one_of_these =~ s/:\^$name:/:$repl:/;
			}
		}
		else {
			# we have a normal line

            my @attr = split(' ',lc($line));# a list of attributes to match against
            #   which we put into an array normalized to lower case
            my $host = $attr[0];       # the first attribute is the host name

			my $wanted = 0;
    			foreach my $attr (@attr) { # iterate over attribute array
       		 		if (index(lc($one_of_these),":$attr:") >= 0) {
	       		 		$wanted++;
				}
       		 		if (index(lc($one_of_these),":^$attr:") >= 0) {
       		 			$wanted = 0;
					last;
				}
    			}
			push(@repl,$host) if ($wanted > 0);
		}
	        next;
	}
	@repl;
}

# sets the BACKBONES variable depending on argument
sub Expanded {
	my(@type) = @_;
	return ParseGhosts(0,@type);
}

# Find the user's GHOSTS file:
# one of $HOME/.ghosts, $HOME/.config/ghosts, $HOME/etc/ghosts
# whichever is found first.  If no file is found, then FALSE is returned.
sub UserConfig {
   my @GHOSTS_USER = ('/.ghosts', '/.config/ghosts', '/etc/ghosts');
   my $HOME = $ENV{HOME};
   foreach my $config (map { $HOME . $_ } @GHOSTS_USER) {
      return $config if -e $config;
   }
   return '';
}

1;
