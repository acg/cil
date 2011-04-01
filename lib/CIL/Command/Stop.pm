## ----------------------------------------------------------------------------
# cil is a Command line Issue List
# Copyright (C) 2008 Andrew Chilton
#
# This file is part of 'cil'.
#
# cil is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.
#
## ----------------------------------------------------------------------------

package CIL::Command::Stop;

use strict;
use warnings;

use base qw(CIL::Command);

## ----------------------------------------------------------------------------

sub name { 'stop' }

sub run {
    my ($self, $cil, $args) = @_;

    ### Read and update the user's timesheet.

    my $issue;
    my $timesheet;
    
    $timesheet = CIL::TimeSheet->new( $cil->UserName );
    $timesheet->load( $cil );
    $issue = $timesheet->stop_work( $cil, $args->{comment} );
    $timesheet->commit( $cil );

    ### If an issue was found and updated, save changes.

    if ($issue)
    {
        $issue->save( $cil ) if $issue;

        if ( $cil->UseGit ) {
            # if we want to add or commit this issue
            if ( $args->{add} or $args->{commit} ) {
                $cil->git->add( $cil, $issue );
                $cil->git->add( $cil, $timesheet );
            }

            # if we want to commit this issue
            if ( $args->{commit} ) {
                $cil->git->commit( $cil, 'Stopped Work', $issue );
            }
        }

        CIL::Utils->display_issue_summary($issue);
    }
}

1;
## ----------------------------------------------------------------------------
