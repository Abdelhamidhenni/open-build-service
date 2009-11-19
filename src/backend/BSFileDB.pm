#
# Copyright (c) 2006, 2007 Michael Schroeder, Novell Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
################################################################
#
# Simple CSV based database functions
#

package BSFileDB;

use strict;

use Fcntl qw(:DEFAULT :flock);

sub decode_line {
  my ($line, $lay) = @_;
  my @line = split('\|', $line);
  s/%([a-fA-F0-9]{2})/chr(hex($1))/ge for @line;
  my @lay = @$lay;
  my $r = {};
  $r->{shift @lay} = shift @line while @lay && @line;
  return $r;
}

sub encode_line {
  my ($r, $lay) = @_;
  my @line;
  for (@$lay) {
    push @line, defined($r->{$_})  ? $r->{$_} : '';
  }
  s/([\000-\037%|=\177-\237])/sprintf("%%%02X", ord($1))/ge for @line; 
  return join('|', @line);
}

sub fdb_getlast {
  my ($fn, $lay) = @_;
  local *F;
  open(F, '<', $fn) || return undef;
  my $off = 1024;
  my $d;
  while (1) {
    my $pos = sysseek(F, -$off, 2);
    if (!defined($pos)) {
      sysseek(F, 0, 0);
      $pos = 0;
    }
    $d = '';
    1 while sysread(F, $d, 8192, length($d));
    return undef unless length $d;
    if (chop($d) ne "\n") {
      if (!($d =~ s/\n[^\n]*$//s)) {
	return undef unless $pos;
	$off += 1024;
	next;
      }
    }
    if ($d =~ /\n([^\n]*)$/s) {
      $d = $1;
      last;
    }
    last unless $pos;
    $off += 1024;
  }
  close F;
  return decode_line($d, $lay);
}

sub fdb_getmatch {
  my ($fn, $lay, $field, $data, $retlast) = @_;

  my $isfirst = $lay->[0] eq $field;
  $data =~ s/([\000-\037|=\177-\237])/sprintf("%%%02X", ord($1))/ge;
  local *F;
  if (ref($fn)) {
    *F = *$fn;
  } else {
    open(F, '<', $fn) || return undef;
  }
  my ($d, $found, $lastd);
  
  if (seek(F, -4096, 2) && defined(<F>)) {
    while (defined($d = <F>)) {
      if (chop($d) ne "\n") {
	undef $d;
	undef $lastd;
	last;
      }
      $lastd = $d;
      if ($isfirst) {
        if ($d eq $data || substr($d, 0, length($data) + 1) eq "$data|") {
	  $found = decode_line($d, $lay);
	  last unless $retlast;
	}
      } elsif ($d =~ /\|\Q$data\E/) {
	$found = decode_line($d, $lay);
	undef $found if $found->{$field} ne $data;
      }
    }
  }
  $found || seek(F, 0, 0) || die("$fn: seek error\n");
  if (!$found) {
    while (defined($d = <F>)) {
      if (chop($d) ne "\n") {
	undef $d;
	undef $lastd;
	last;
      }
      $lastd = $d;
      if ($isfirst) {
        if ($d eq $data || substr($d, 0, length($data) + 1) eq "$data|") {
	  $found = decode_line($d, $lay);
	  last unless $retlast;
	}
      } elsif ($d =~ /\|\Q$data\E/) {
	$found = decode_line($d, $lay);
	undef $found if $found->{$field} ne $data;
      }
    }
  }
  close F unless ref $fn;
  return ($lastd, $found) if $retlast;
  return $found;
}

sub fdb_getall {
  my ($fn, $lay, $limit, $filter) = @_;

  local *F;
  open(F, '<', $fn) || return ();
  my @res;
  while (<F>) {
    next if chop($_) ne "\n";
    my $r = decode_line($_, $lay);
    if ($filter) {
      my $f = $filter->($r);
      next unless $f;
      last if $f < 0;
    }
    push @res, $r;
    shift @res if defined($limit) && @res > $limit;
  }
  close F;
  return @res;
}

# read file in reverse order
# we read in 32K chunks
sub fdb_getall_reverse {
  my ($fn, $lay, $limit, $filter) = @_;

  local *F;
  open(F, '<', $fn) || return ();
  my @s = stat(F);
  if (!@s) {
    close F;
    return ();
  }
  my $pos = 0;
  my $len = $s[7];
  if ($len > 0x7fff) {
    $pos = ($len - 0x7fff) & ~0x7fff;
    $len = $len - $pos;
  }
  my $tail = '';
  my @res;
  while ($len) {
    last unless defined(sysseek(F, $pos, 0));
    my $buf = '';
    last unless (sysread(F, $buf, $len) || 0) == $len;
    $buf .= $tail;
    if ($pos) {
      if ($buf =~ /^(.*?\n)/s) {
	$tail = $1; 
	$buf = substr($buf, length($tail));
      } else {
	$tail = $buf;
	$buf = ''; 
      }   
      $pos -= 0x8000;
      $len = 0x8000;
    } else {
      $tail = '';
      $len = 0;
    }
    my @l; 
    if (chop($buf) ne "\n") {
      @l = split("\n", $buf, -1);
      pop @l; 
    } else {
      @l = split("\n", $buf, -1);
    }
    for (reverse @l) {
      my $r = decode_line($_, $lay);
      if ($filter) {
        my $f = $filter->($r);
	next unless $f;
        $len = 0, last if $f < 0;
      }
      push @res, $r;
      $len = 0, last if defined($limit) && @res >= $limit;
    }
  }
  close F;
  return @res;
}

sub fdb_add_i {
  my ($fn, $lay, $r) = @_;
  local *F;
  open(F, '+>>', $fn) || die("$fn: $!\n");
  flock(F, LOCK_EX) || die("$fn: $!\n");
  my $num = 0;
  my $end = sysseek(F, 0, 2);
  die("sysseek: $!\n") unless defined $end;
  my $d;
  $end = 0 + $end;
  if ($end) {
    my $pos = $end - 1024;
    while(1) {
      $pos = 0 if $pos < 0;
      defined(sysseek(F, $pos, 0)) || die("sysseek: $!\n");
      (sysread(F, $d, $end - $pos + 1) || 0) == $end - $pos || die("$fn: read error\n");
      chop($d) eq "\n" || die("$fn: bad last line");
      if ($d =~ /\n([^\n]*)$/s) {
	$d = $1;
	last;
      }
      last unless $pos;
      $pos -= 1024;
    }
    die("$fn: bad last line\n") unless $d =~ /^(\d+)/;
    $num = $1;
  }
  $num++;
  $r->{$lay->[0]} = $num;
  $d = encode_line($r, $lay)."\n";
  (syswrite(F, $d) || 0) == length($d) || die("$fn write error: $!\n");
  close(F) || die("$fn write error: $!\n");
  return $r;
}

# double increment add, increment first and field of last record
# that matches mfield:mdata
sub fdb_add_i2 {
  my ($fn, $lay, $r, $field, $mfield, $mdata) = @_;
  local *FN;
  open(FN, '+>>', $fn) || die("$fn: $!\n");
  flock(FN, LOCK_EX) || die("$fn: $!\n");
  my ($d2, $r2) = fdb_getmatch(\*FN, $lay, $mfield, $mdata, 1);
  if (!defined($d2)) {
    my @s = stat(FN);
    die("$fn: bad last line\n") if $s[7];
    $d2 = "0";
  }
  $d2 = decode_line($d2, $lay);
  $d2 = $d2->{$lay->[0]} || 0;
  $r2 = {$field => 0} unless $r2;
  $r2 = $r2->{$field} || 0;
  $r->{$lay->[0]} = $d2 + 1;
  $r->{$field} ||= 0;
  $r->{$field} = $r2 + 1 if $r2 + 1 > $r->{$field};
  $d2 = encode_line($r, $lay)."\n";
  (syswrite(FN, $d2) || 0) == length($d2) || die("$fn write error: $!\n");
  close(FN) || die("$fn write error: $!\n");
  return $r;
}

sub fdb_add {
  my ($fn, $lay, $r) = @_;
  local *FN;
  open(FN, '+>>', $fn) || die("$fn: $!\n");
  flock(FN, LOCK_EX) || die("$fn: $!\n");
  my $d = encode_line($r, $lay)."\n";
  (syswrite(FN, $d) || 0) == length($d) || die("$fn write error: $!\n");
  close(FN) || die("$fn write error: $!\n");
  return $r;
}

1;
