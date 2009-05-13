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
# parameter verification functions
#

package BSVerify;

use strict;

sub verify_projid {
  my $projid = $_[0];
  die("projid is empty\n") unless defined($projid) && $projid ne '';
  die("projid '$projid' is illegal\n") if $projid =~ /[\/\000-\037]/;
  die("projid '$projid' is illegal\n") if ":$projid:" =~ /:[_\.:]/;
}

sub verify_packid {
  my $packid = $_[0];
  die("packid is empty\n") unless defined($packid) && $packid ne '';
  $packid =~ s/^_product://s;
  die("packid '$packid' is illegal\n") if $packid =~ /[\/:\000-\037]/;
  die("packid '$packid' is illegal\n") if $packid =~ /^[_\.]/ and $packid ne '_product' and $packid ne '_pattern';
}

sub verify_repoid {
  my $repoid = $_[0];
  die("repoid is empty\n") unless defined($repoid) && $repoid ne '';
  die("repoid '$repoid' is illegal\n") if $repoid =~ /[\/:\000-\037]/;
  die("repoid '$repoid' is illegal\n") if $repoid =~ /^[_\.]/;
}

sub verify_jobid {
  my $jobid = $_[0];
  die("jobid is empty\n") unless defined($jobid) && $jobid ne '';
  die("jobid '$jobid' is illegal\n") if $jobid =~ /[\/\000-\037]/;
  die("jobid '$jobid' is illegal\n") if $jobid =~ /^[\.]/;
}

sub verify_arch {
  my $arch = $_[0];
  die("arch is empty\n") unless defined($arch) && $arch ne '';
  die("arch '$arch' is illegal\n") if $arch =~ /[\/:\.\000-\037]/;
}

sub verify_packid_repository {
  verify_packid($_[0]) unless $_[0] && $_[0] eq '_repository';
}

sub verify_packid_pattern {
  verify_packid($_[0]) unless $_[0] && $_[0] eq '_pattern';
}

sub verify_packid_product {
  verify_packid($_[0]) unless $_[0] && $_[0] eq '_product';
}

sub verify_filename {
  my $filename = $_[0];
  die("filename is empty\n") unless defined($filename) && $filename ne '';
  die("filename '$filename' is illegal\n") if $filename =~ /[\/\000-\037]/;
  die("filename '$filename' is illegal\n") if $filename =~ /^\./;
}

sub verify_md5 {
  my $md5 = $_[0];
  die("not a md5 sum\n") unless $md5 && $md5 =~ /^[0-9a-f]{32}$/s;
}

sub verify_rev {
  my $rev = $_[0];
  die("revision is empty\n") unless defined($rev) && $rev ne '';
  return if $rev =~ /^[0-9a-f]{32}$/s;
  return if $rev eq 'upload' || $rev eq 'build' || $rev eq 'latest' || $rev eq 'repository';
  die("bad revision '$rev'\n") unless $rev =~ /^\d+$/s;
}

sub verify_linkrev {
  my $rev = $_[0];
  return if $rev && $rev eq 'base';
  verify_rev($rev);
}

sub verify_port {
  my $port = $_[0];
  die("port is empty\n") unless defined($port) && $port ne '';
  die("bad port '$port'\n") unless $port =~ /^\d+$/s;
  die("illegal port '$port'\n") unless $port >= 1024;
}

sub verify_num {
  my $num = $_[0];
  die("number is empty\n") unless defined($num) && $num ne '';
  die("not a number: '$num'\n") unless $num =~ /^\d+$/;
}

sub verify_bool {
  my $bool = $_[0];
  die("not boolean\n") unless defined($bool) && ($bool eq '0' || $bool eq '1');
}

sub verify_prp {
  my $prp = $_[0];
  die("not a prp: '$prp'\n") unless $prp =~ /^([^\/]*)\/(.*)$/s;
  my ($projid, $repoid) = ($1, $2);
  verify_projid($projid);
  verify_repoid($repoid);
}

sub verify_prpa {
  my $prpa = $_[0];
  die("not a prpa: '$prpa'\n") unless $prpa =~ /^(.*)\/([^\/]*)$/s;
  my ($prp, $arch) = ($1, $2);
  verify_prp($prp);
  verify_arch($arch);
}

sub verify_resultview {
  my $view = $_[0];
  die("unknown view parameter: '$view'\n") if $view ne 'summary' && $view ne 'status' && $view ne 'binarylist';
}

sub verify_disableenable {
  my ($disen) = @_;
  for my $d (@{$disen->{'disable'} || []}, @{$disen->{'enable'} || []}) {
    verify_repoid($d->{'repository'}) if exists $d->{'repository'};
    verify_arch($d->{'arch'}) if exists $d->{'arch'};
  }
}

sub verify_proj {
  my ($proj, $projid) = @_;
  if (defined($projid)) {
    die("name does not match data\n") unless $projid eq $proj->{'name'};
  }
  verify_projid($proj->{'name'});
  my %got_pack;
  for my $pack (@{$proj->{'package'} || []}) {
    verify_packid($pack->{'name'});
    die("package $pack->{'name'} listed more than once\n") if $got_pack{$pack->{'name'}};
    $got_pack{$pack->{'name'}} = 1;
  }
  my %got;
  for my $repo (@{$proj->{'repository'} || []}) {
    verify_repoid($repo->{'name'});
    die("repository $repo->{'name'} listed more than once\n") if $got{$repo->{'name'}};
    $got{$repo->{'name'}} = 1;
    for my $r (@{$repo->{'path'} || []}) {
      verify_projid($r->{'project'});
      verify_repoid($r->{'repository'});
    }
    for my $a (@{$repo->{'arch'} || []}) {
      verify_arch($a);
    }
  }
  for my $f ('build', 'publish', 'debuginfo', 'useforbuild') {
    verify_disableenable($proj->{$f}) if $proj->{$f};
  }
}

sub verify_pack {
  my ($pack, $packid) = @_;
  if (defined($packid)) {
    die("name does not match data\n") unless $packid eq $pack->{'name'};
  }
  verify_disableenable($pack);	# obsolete
  for my $f ('build', 'debuginfo', 'useforbuild', 'publish') {
    verify_disableenable($pack->{$f}) if $pack->{$f};
  }
  if ($pack->{'devel'}) {
    verify_projid($pack->{'devel'}->{'project'});
    verify_packid($pack->{'devel'}->{'package'}) if exists $pack->{'devel'}->{'package'};
  }
}

sub verify_link {
  my ($l) = @_;
  verify_projid($l->{'project'}) if exists $l->{'project'};
  verify_packid($l->{'package'}) if exists $l->{'package'};
  verify_rev($l->{'rev'}) if exists $l->{'rev'};
  die("link must contain some target description \n") unless exists $l->{'project'} || exists $l->{'package'} || exists $l->{'rev'};
  if (exists $l->{'cicount'}) {
    if ($l->{'cicount'} ne 'add' && $l->{'cicount'} ne 'copy' && $l->{'cicount'} ne 'local') {
      die("unknown cicount '$l->{'cicount'}'\n");
    }
  }
  return unless $l->{'patches'} && $l->{'patches'}->{''};
  for my $p (@{$l->{'patches'}->{''}}) {
    die("more than one type in patch\n") unless keys(%$p) == 1;
    my $type = (keys %$p)[0];
    my $pd = $p->{$type};
    if ($type eq 'add' || $type eq 'apply' || $type eq 'delete') {
      verify_filename($pd->{'name'});
    } elsif ($type ne 'topadd') {
      die("unknown patch type '$type'\n");
    }
  }
}

sub verify_aggregatelist {
  my ($al) = @_;
  for my $a (@{$al->{'aggregate'} || []}) {
    verify_projid($a->{'project'});
    for my $p (@{$a->{'package'} || []}) {
      verify_packid($p);
    }
    for my $b (@{$a->{'binary'} || []}) {
      verify_filename($b);
    }
    for my $r (@{$a->{'repository'} || []}) {
      verify_repoid($r->{'source'}) if exists $r->{'source'};
      verify_repoid($r->{'target'}) if exists $r->{'target'};
    }
  }
}

sub verify_request {
  my ($req) = @_;
  die("request must contain a state\n") unless $req->{'state'};
  die("request must contain a state name\n") unless $req->{'state'}->{'name'};
  die("request contains unknown state ".$req->{'state'}->{'name'}."\n")
     unless $req->{'state'}->{'name'} eq "new" or $req->{'state'}->{'name'} eq "revoked" 
         or $req->{'state'}->{'name'} eq "accepted" or $req->{'state'}->{'name'} eq "declined"
         or $req->{'state'}->{'name'} eq "deleted";

  my $requests;
  if ($req->{'type'} && $req->{'type'} eq 'submit' && $req->{'submit'}) {
    # old style submit requests
    push @$requests, $req->{'submit'};
  }else{
    $requests = $req->{'request'};
  };
  die("No request specified\n") unless $requests;
  for my $r (@{$requests || []}) {
    if ($r->{'type'} eq 'delete') {
      die("delete target specification missing\n") unless $r->{'target'};
      die("delete target project specification missing\n") unless $r->{'target'}->{'project'};
      verify_projid($r->{'target'}->{'project'});
      verify_packid($r->{'target'}->{'package'}) if exists $r->{'target'}->{'package'};
    } elsif ($r->{'type'} eq 'submit' || $req->{'submit'}) {
      die("submit source missing\n") unless $r->{'source'};
      die("submit target missing\n") unless $r->{'target'};
      verify_projid($r->{'source'}->{'project'});
      verify_projid($r->{'target'}->{'project'});
      verify_packid($r->{'source'}->{'package'});
      verify_packid($r->{'target'}->{'package'});
      verify_rev($r->{'source'}->{'rev'}) if exists $r->{'source'}->{'rev'};
    } else {
      die("No request type specified\n") unless $r->{'type'};
      die("unknown request type '$r->{'type'}'\n");
    }
  }
}

sub verify_nevraquery {
  my ($q) = @_;
  verify_arch($q->{'arch'});
  my $f = "$q->{'name'}-$q->{'version'}";
  $f .= "-$q->{'release'}" if defined $q->{'release'};
  verify_filename($q->{'arch'});
}

our $verifyers = {
  'project' => \&verify_projid,
  'package' => \&verify_packid,
  'repository' => \&verify_repoid,
  'arch' => \&verify_arch,
  'job' => \&verify_jobid,
  'package_repository' => \&verify_packid_repository,
  'package_pattern' => \&verify_packid_pattern,
  'package_product' => \&verify_packid_product,
  'filename' => \&verify_filename,
  'md5' => \&verify_md5,
  'rev' => \&verify_rev,
  'linkrev' => \&verify_linkrev,
  'bool' => \&verify_bool,
  'num' => \&verify_num,
  'port' => \&verify_port,
  'prp' => \&verify_prp,
  'prpa' => \&verify_prpa,
  'resultview' => \&verify_resultview,
};

1;
