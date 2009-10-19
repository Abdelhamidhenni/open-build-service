#
# Copyright (c) 2006, 2007 Michael Schroeder, Novell Inc.
# Copyright (c) 2008 Adrian Schroeter, Novell Inc.
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
# XML templates for the BuildService. See XML/Structured.
#

package BSXML;

use strict;

# 
# an explained example entry of this file
#
#our $pack = [             creates <package name="" project=""> space
#    'package' =>          
#	'name',
#	'project',
#	[],                before the [] all strings become attributes to <package>
#       'title',           from here on all strings become children like <title> </title>
#       'description',
#       [[ 'person' =>     creates <person> children, the [[ ]] syntax allows any number of them including zero
#           'role',        again role and userid attributes, both are required
#           'userid',    
#       ]],                this block describes a <person role="defeatist" userid="statler" /> construct
# 	@flags,            copies in the block of possible flag definitions
#       [ $repo ],         refers to the repository construct and allows again any number of them (0-X)
#];                        closes the <package> child with </package>

our $repo = [
   'repository' => 
	'name',
     [[ 'path' =>
	    'project',
	    'repository',
     ]],
      [ 'arch' ],
	'status',
];

our @disableenable = (
     [[	'disable' =>
	'arch',
	'repository',
     ]],
     [[	'enable' =>
	'arch',
	'repository',
     ]],
);

our @flags = (
      [ 'build' => @disableenable ],
      [ 'publish' => @disableenable ],
      [ 'debuginfo' => @disableenable ],
      [ 'useforbuild' => @disableenable ],
      [ 'binarydownload' => @disableenable ],
);

our $download = [
    'download' =>
     'baseurl',
     'metafile',
     'mtype',
     'arch',
];

our $proj = [
    'project' =>
        'name',
	 [],
        'title',
        'description',
	'remoteurl',
	'remoteproject',
     [[ 'person' =>
            'role',
            'userid',
     ]],
     [ $download ],
     [ 'attributes' => 
       [[ 'namespace' => 
            'name', 
            [[ 'modifiable_by' =>
               'name',
               'group',
               'role',
            ]],
       ]],
       [[ 'definition' => 
            'name', 
            'namespace', 
            'type' =>
            [ 'default' =>
               [[ 'value' => '_content' ]],
            ],
            [ 'allowed' =>
               [[ 'value' => '_content' ]],
            ],
            [[ 'modifiable_by' =>
               'name',
               'group',
               'role',
            ]],
       ]],
     ],
	@flags,
      [ $repo ],
];

our $pack = [
    'package' =>
	'name',
	'project',
	[],
        'title',
        'description',
      [ 'devel', =>
	    'project',
	    'package',
      ],
      [ 'attributes', => 
        [[ 'attribute', => 
              'name',
              'package', =>
                 [[ 'value' => '_content' ]]
        ]],
      ],
     [[ 'person' =>
            'role',
            'userid',
     ]],
	@disableenable,
	@flags,
	'url',
	'group',	# obsolete?
	'bcntsynctag',
];

our $packinfo = [
    'info' =>
	'repository',
	'name',
	'file',
	'error',
	  [ 'dep' ],
	  [ 'prereq' ],
	  [ 'imagetype' ],
	 [[ 'path' =>
		'project',
		'repository',
	]],
	 [[ 'extrasource' =>
		'project',
		'package',
		'srcmd5',
		'file',
	 ]],
];

our $linked = [
    'linked' =>
	'project',
	'package',
];

our $aggregatelist = [
    'aggregatelist' =>
     [[ 'aggregate' =>
	    'project',
	  [ 'package' ],
	  [ 'binary' ],
	 [[ 'repository' =>
		'target',
		'source',
         ]],
     ]],
];

our $projpack = [
    'projpack' =>
     [[ 'project' =>
	    'name',
	     [],
	    'title',
	    'description',
	    'config',
	    'patternmd5',
	    'remoteurl',
	    'remoteproject',
	    @flags,
	  [ $repo ],
          [ $download ],
	 [[ 'package' =>
		'name',
		'rev',
		'srcmd5',
		'versrel',
		'verifymd5',
		[ $linked ],
		'error',
		[ $packinfo ],
		$aggregatelist,
		@flags,
		'bcntsynctag',
	 ]],
     ]],
     [[ 'remotemap' =>
	    'project',
	    'remoteurl', 
	    'remoteproject', 
     ]],
];

our $linkinfo = [
    'linkinfo' =>
	# information from link
	'project',
	'package',
	'rev',
	'srcmd5',
	'baserev',
	# expanded / unexpanded srcmd5
	'xsrcmd5',
	'lsrcmd5',
	'error',
	'lastworking',
];


our $dir = [
    'directory' =>
	'name',
	'count',	# obsolete, the API sets this for some requests
	'rev',
	'vrev',
	'srcmd5',
        'tproject',
        'tpackage',
        'trev',
        'tsrcmd5',
        'lsrcmd5',
        'error',
        'xsrcmd5',
        $linkinfo,
     [[ 'entry' =>
	    'name',
	    'md5',
	    'size',
	    'mtime',
	    'error',
	    'id',
     ]]
];

our $fileinfo = [
    'fileinfo' =>
	'filename',
	[],
	'name',
        'epoch',
	'version',
	'release',
	'arch',
	'summary',
	'description',
	'size',
      [ 'provides' ],
      [ 'requires' ],
      [ 'prerequires' ],
      [ 'conflicts' ],
      [ 'obsoletes' ],
      [ 'recommends' ],
      [ 'supplements' ],
      [ 'suggests' ],
      [ 'enhances' ],
];

our $buildinfo = [
    'buildinfo' =>
	'project',
	'repository',
	'package',
	'reposerver',
	'downloadurl',
	[],
	'job',
	'arch',
	'error',
	'srcmd5',
	'verifymd5',
	'rev',
	'reason',       # just for the explain string of a build reason
	'specfile',	# obsolete
	'file',
	'versrel',
	'bcnt',
	'release',
	'debuginfo',
      [ 'subpack' ],
      [ 'imagetype' ],
      [ 'dep' ],
     [[ 'bdep' =>
	'name',
	'preinstall',
	'vminstall',
	'runscripts',
	'notmeta',
	'noinstall',

	'epoch',
	'version',
	'release',
	'arch',
	'project',
	'repository',
	'repoarch',
	'package',
	'srcmd5',
     ]],
      [ 'pdep' ],	# obsolete
     [[ 'path' =>
	    'project',
	    'repository',
	    'server',
     ]]
];

our $jobstatus = [
    'jobstatus' =>
	'code',
	'result',       # succeeded, failed or unchanged
	'details',
	[],
	'starttime',
	'endtime',
	'workerid',
	'hostarch',

	'uri',		# uri to reach worker

	'arch',		# our architecture
	'job',		# our jobname
	'jobid',	# md5 of job info file
];

our $buildreason = [
    'reason' =>
       [],
       'explain',             # Readable reason
       'time',                # unix time from start build
       'oldsource',           # last build source md5 sum, if a source change was the reason
       [[ 'packagechange' =>  # list changed files which are used for building
          'change',           # kind of change (content/meta change, additional file or removed file)
          'key',              # file name
       ]],
];

our $buildstatus = [
    'status' =>
	'package',
	'code',
	'status',	# obsolete, now code
	'error',	# obsolete, now details
	[],
	'details',

	'workerid',	# last build data
	'hostarch',
	'readytime',
	'starttime',
	'endtime',

	'job',		# internal, job when building

	'uri',		# obsolete
	'arch',		# obsolete
];

our $builddepinfo = [
    'builddepinfo' =>
     [[ 'package' =>
	    'name',
	    [],
	    'source',
	  [ 'pkgdep' ],
	  [ 'subpkg' ],
     ]],
];

our $event = [
    'event' =>
	'type',
	[],
	'project',
	'repository',
	'arch',
	'package',
	'job',
	'due',
];

our $events = [
    'events' =>
	'next',
	'sync',
       [ $event ],
];

our $revision = [
     'revision' =>
	'rev',
	'vrev',
	[],
	'srcmd5',
	'version',
	'time',
	'user',
	'comment',
	'requestid',
];

our $revisionlist = [
    'revisionlist' =>
      [ $revision ]
];

our $buildhist = [
    'buildhistory' =>
     [[ 'entry' =>
	    'rev',
	    'srcmd5',
	    'versrel',
	    'bcnt',
	    'time',
     ]],
];

our $binaryversionlist = [
    'binaryversionlist' =>
      [[ 'binary' =>
	    'name',
	    'sizek',
	    'error',
	    'hdrmd5',
	    'metamd5',
      ]],
];

our $worker = [
    'worker' =>
	'hostarch',
	'ip',
	'port',
	'workerid',
      [ 'buildarch' ],
	'memory',	# in MBytes
	'disk',		# in MBytes
	'tellnojob',

	'job',		# set when worker is busy
	'arch',		# set when worker is busy
];

our $packstatuslist = [
    'packstatuslist' =>
	'project',
	'repository',
	'arch',
     [[ 'packstatus' =>
	    'name',
	    'status',
	    'error',
     ]],
     [[ 'packstatussummary' =>
	    'status',
	    'count',
     ]],
];

our $packstatuslistlist = [
    'packstatuslistlist' =>
    'state',
    'retryafter',
     [ $packstatuslist ],
];

our $linkpatch = [
    '' =>
      [ 'add' =>
	    'name',
	    'type',
	    'after',
	    'popt',
	    'dir',
      ],
      [ 'apply' =>
	    'name',
      ],
      [ 'delete' =>
	    'name',
      ],
        'topadd',
];

our $link = [
    'link' =>
	'project',
	'package',
	'rev',
	'cicount',
	'baserev',
      [ 'patches' =>
	  [ $linkpatch ],
      ],
];

our $workerstatus = [
    'workerstatus' =>
	'clients',
     [[ 'idle' =>
	    'uri',
	    'workerid',
	    'hostarch',
     ]], 
     [[ 'building' =>
	    'uri',
	    'workerid',
	    'hostarch',
	    'project',
	    'repository',
	    'package',
	    'arch',
	    'starttime',
     ]],
     [[ 'waiting', =>
	    'arch',
	    'jobs',
     ]],
     [[ 'blocked', =>
	    'arch',
	    'jobs',
     ]],
     [[ 'buildavg', =>
            'arch',
	    'buildavg',
     ]],
     [[ 'scheduler' =>
	    'arch',
	    'state',
	    'starttime',
     ]],
];

our $workerstate = [
    'workerstate' =>
	'state',
	'jobid',
];

our $jobhistlay = [
	'package',
	'rev',
	'srcmd5',
	'versrel',
	'bcnt',
	'readytime',
	'starttime',
	'endtime',
	'code',
	'uri',
	'workerid',
	'hostarch',
	'reason',
];

our $jobhist = [
    'jobhist' =>
	@$jobhistlay,
];

our $jobhistlist = [
    'jobhistlist' =>
      [ $jobhist ],
];

our $ajaxstatus = [
    'ajaxstatus' =>
     [[ 'watcher' =>
	    'filename',
	    'state',
	 [[ 'job' =>
		'id',
		'ev',
		'fd',
		'peer',
	 ]],
     ]],
     [[ 'rpc' =>
	    'uri',
	    'state',
	    'ev',
	    'fd',
	 [[ 'job' =>
		'id',
		'ev',
		'fd',
		'peer',
	 ]],
     ]],
];

##################### new api stuff

our $binarylist = [
    'binarylist' =>
	'package',
     [[ 'binary' =>
	    'filename',
	    'size',
	    'mtime',
     ]],
];

our $summary = [
    'summary' =>
     [[ 'statuscount' =>
	    'code',
	    'count',
     ]],
];

our $result = [
    'result' =>
	'project',
	'repository',
	'arch',
      [ $buildstatus ],
      [ $binarylist ],
        $summary,
];

our $resultlist = [
    'resultlist' =>
	'state',
	'retryafter',
      [ $result ],
];

our $opstatus = [
    'status' =>
	'code',
	[],
	'summary',
	'details',
        [ 'exception' =>
            'type',
            'message',
            [ 'backtrace' =>
                [ 'line',
                ],
            ],
        ],
];

my $rpm_entry = [
    'rpm:entry' =>
        'kind',
        'name',
        'epoch',
        'ver',
        'rel',
        'flags',
];

our $pattern = [
    'pattern' =>
	'xmlns',      # obsolete, moved to patterns
	'xmlns:rpm',  # obsolete, moved to patterns
	[],
	'name',
     [[ 'summary' =>
	    'lang',
	    '_content',
     ]],
     [[ 'description' =>
	    'lang',
	    '_content',
     ]],
	'default',
	'uservisible',
     [[ 'category' =>
	    'lang',
	    '_content',
     ]],
	'icon',
	'script',
      [ 'rpm:provides' => [ $rpm_entry ], ],
      [ 'rpm:conflicts' => [ $rpm_entry ], ],
      [ 'rpm:obsoletes' => [ $rpm_entry ], ],
      [ 'rpm:requires' => [ $rpm_entry ], ],
      [ 'rpm:suggests' => [ $rpm_entry ], ],
      [ 'rpm:enhances' => [ $rpm_entry ], ],
      [ 'rpm:supplements' => [ $rpm_entry ], ],
      [ 'rpm:recommends' => [ $rpm_entry ], ],
];

our $patterns = [
    'patterns' =>
	'count',
	'xmlns',
	'xmlns:rpm',
	[],
      [ $pattern ],
];

our $ymp = [
    'metapackage' =>
        'xmlns:os',
        'xmlns',
        [],
     [[ 'group' =>
	    'recommended',
	    'distversion',
	    [],
	    'name',
	    'summary',
	    'description',
	    'remainSubscribed',
	  [ 'repositories' =>
	     [[ 'repository' =>
		    'recommended',
		    'format',
		    'producturi',
		    [],
		    'name',
		    'summary',
		    'description',
		    'url',
	     ]],
	    ],
	  [ 'software' =>
	     [[ 'item' =>
		    'type',
		    'recommended',
		    'architectures',
		    'action',
		    [],
		    'name',
		    'summary',
		    'description',
	     ]],
	  ],
      ]],
];

our $binary_id = [
    'binary' => 
	'name',
	'project',
	'package',
	'repository',
	'version',
	'arch',
	'filename',
	'filepath',
	'baseproject',
	'type',
];

our $pattern_id = [
    'pattern' => 
	'name',
	'project',
	'repository',
	'arch',
	'filename',
	'filepath',
	'baseproject',
	'type',
];

our $request = [
    'request' =>
	'id',
	'type',             # obsolete in future, type will be defined per action
     [[ 'action' =>
	   'type',          # currently submit, delete, change_devel
	   [ 'source' =>
	         'project',
	         'package',
	         'rev',
	   ],
	   [ 'target' =>
	         'project',
	         'package',
	   ],
           [ 'options' =>
                 [],
	         'sourceupdate', # can be cleanup, update or noupdate
           ],
     ]],
      [ 'submit' =>          # this is old style, obsolete by request, but still supported
	  [ 'source' =>
		'project',
		'package',
		'rev',
	  ],
	  [ 'target' =>
		'project',
		'package',
	  ],
      ],
      [ 'state' =>
	    'name',
	    'who',
	    'when',
	    [],
	    'comment',
      ],
     [[ 'history' =>
	    'name',
	    'who',
	    'when',
	    [],
	    'comment',
     ]],
	'title',
	'description',
];

our $repositorystate = [
    'repositorystate' => 
      [ 'blocked' ],
];

our $collection = [
    'collection' => 
      [ $request ],
      [ $proj ],
      [ $pack ],
      [ $binary_id ],
      [ $pattern_id ],
      [ 'value' ],
];

our $quota = [
    'quota' =>
	'packages',
     [[ 'project' =>
	    'name',
	    'packages',
     ]],
];

our $services = [
    'services' =>
    [[ 'service' =>
       'name',
       [],
       [[ 'param' => 'name', '_content' ]],
    ]],
];

our $schedulerinfo = [
  'schedulerinfo' =>
	'arch',
	'started',
	'time',
	[],
	'slept',
	'notready',
      [ 'queue' =>
	    'high',
	    'med',
	    'low',
	    'next',
      ],
	'projects',
	'repositories',
     [[ 'worst' =>
	    'project',
	    'repository',
	    'packages',
	    'time',
     ]],
        'buildavg',
	'avg',
	'variance',
];

our $person = [
  'person' =>
	'login',
	'email',
	'realname',
	[ 'watchlist' =>
		[[ 'project' =>
			'name',
		]],
	],
];


1;
