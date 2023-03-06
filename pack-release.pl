#!/usr/bin/perl -w
use strict qw(vars subs);
use warnings;
use Cwd;

use Data::Dumper qw(Dumper);

my $cwd = getcwd();
print "cwd $cwd\n";
my $package = 'tuxedo-tomte';
my $prefix;
my $version;
my $changelog = "$cwd"."/debian/changelog";
my $branch = `git symbolic-ref --short HEAD`;
my $gbpConf = "$cwd"."/debian/gbp.conf";
my $debugMode = 0;
my $presentTODO = 0;
$branch =~ s/\s//g;


print "on branch: $branch<\n\n";

open my $FH, '<', './src/tuxedo-tomte';
while (my $line = <$FH>) {
	if ($line =~ /#TODO/) {
		print "#########################################\n";
		print "#########################################\n";
		print "     WARNING! '#TODO' in file!!!         \n";
		print "#########################################\n";
		print "#########################################\n";
		$presentTODO = 1;
	}
	if (($line =~ /my \$logLevel =/) && ($line !~ /my \$logLevel = 0;/)) {
		print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n";
		print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n";
		print "     WARNING! 'Debug level not ZERO!!!   \n";
		print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n";
		print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n";
		$debugMode = 1;
	}
}
close ($FH);

# get version number
print "Old version:\n";
open (CL, $changelog) || die "could not open $changelog\n";
print scalar <CL>;
close CL;
print "New version number? (x.x.x) or test-release (x.x.x-x)\n";
$version = <>;
chomp($version);
$version =~ /^\d+\.\d+\.\d+.*$/ || die "wrong version format\n";
print "got version: $version\n";
if (($version =~ /^\d+\.\d+\.\d+$/) && ($debugMode != 0)) {
	print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n";
	print "\$loglevel not ZERO!!!\n";
	print "for master releases loglevel must be '0'!!!\n";
	print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n";
	exit (0);
}
if (($version =~ /^\d+\.\d+\.\d+$/) && ($presentTODO != 0)) {
	print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n";
	print "TODO's are present!!!\n";
	print "for master releases no TODO's should be present at all!!!\n";
	print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n";
	exit (0);
}

# set version in sourcefile
if (open (my $FHin, '<', './src/tuxedo-tomte')) {
	open (my $FHout, '>', './src/tuxedo-tomte.tmp');
	while (my $line = <$FHin>) {
		if ($line =~ /^our \$VERSION = \'.*\';$/) {
			$line = "our \$VERSION = '$version';\n";
			print "found line changing\n";
		}
		print $FHout $line;
	}
	close ($FHin);
	close ($FHout);
	unlink ($FHin);
	rename './src/tuxedo-tomte.tmp', './src/tuxedo-tomte';
}

$prefix = $package.'_'.$version;
print "prefix: $prefix\n";
sleep(2);

system("gbp dch --verbose --debian-branch $branch --new-version=$version");
system("vim $changelog");
system("cp $changelog $cwd/");

system('git add .');
system('git commit -m \'packing\'');
system('git push');

print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>";
print ">>> building tarball\n";
system("git archive --format=tar --prefix=$prefix/ HEAD | gzip -c > ../$prefix.orig.tar.gz");
print ">>> check tarball content\n";
system("tar tvf ../$prefix.orig.tar.gz");
system("git branch -D debian-debian");
system("git branch -D debian-upstream");
print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>";
system("git checkout --orphan debian-upstream");
system("git rm --cached -r .");
system("git clean -xfd");
system("git commit --allow-empty -m 'Start of debian branches.'");
system("git checkout -b debian-debian");
system("git checkout $branch -- debian/");
system("git add .");
system("git commit -m 'packing'");

my $str = <<END;
[DEFAULT]
upstream-branch=debian-upstream
debian-branch=debian-debian
END

open(FH, '>', $gbpConf);
print FH $str;
close(FH);

system("git add .");
system("git commit -m 'packing'");
print "import\n";
system("gbp import-orig --no-interactive ../$prefix.orig.tar.gz");
print "build\n";
system("gbp buildpackage -us -uc");

# return to original branch
print "returning\n";
system("git checkout $branch");
# commit last changes to debian/file
system("git add .");
system("git commit -m 'after packaging'");
system("git push");
