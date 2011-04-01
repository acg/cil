package CIL::TimeSheet;

use strict;
use warnings;
use Carp;

use CIL::Issue;

use base qw(Class::Accessor);

# fields specific to TimeSheet
__PACKAGE__->mk_accessors(qw( FullName ShortName Worked ));

my @FILE_FIELDS = qw( issue status time0 time1 comment );


sub new
{
    my ($proto, $fullname) = @_;

    croak "please provide a user's full name"
        unless defined $fullname;

    my $shortname = lc $fullname;
    $shortname =~ s#[ /]#_#g;
    die "invalid shortname $shortname" unless $shortname =~ /[a-z0-9]/;

    my $class = ref $proto || $proto;
    my $self = {};
    bless $self, $class;

    $self->{data} = {
        FullName => $fullname,
        ShortName => $shortname,
        Worked => [],
    };

    return $self;
}

sub start_work
{
    my ($self, $cil, $issue, $comment) = @_;
    my $worked = $self->{data}{Worked};
    my $current = $worked->[-1] || {};
    my $now = time;

    ### Already working on an issue? Stop work.

    my $issue_prev;

    if (defined $current && !$current->{time1})
    {
        $current->{time1} = $now;

        if ($issue_prev = CIL::Issue->new_from_name( $cil, $current->{issue} ))
        {
            $issue_prev->Status( $current->{status} );
            $issue_prev->set_updated_now();
        }
    }

    push @$worked, {
        issue => $issue->name,
        status => $issue->Status,
        time0 => $now,
        time1 => '',
        comment => $comment||'',
    };

    $issue->Status( 'InProgress' );
    $issue->set_updated_now();

    return $issue_prev;
}

sub stop_work
{
    my ($self, $cil, $comment) = @_;
    my $worked = $self->{data}{Worked};
    my $current = $worked->[-1] || {};
    my $now = time;

    ### If the current work entry is open, end it, reverting the
    ### issue back to it's prior status.

    my $issue = undef;

    if ($current && !$current->{time1})
    {
        $current->{time1} = $now;
        $current->{comment} = $comment if $comment;

        if ($issue = CIL::Issue->new_from_name( $cil, $current->{issue} ))
        {
            $issue->Status( $current->{status} );
            $issue->set_updated_now();
        }
    }

    return $issue;
}

sub load {
    my ($self, $cil) = @_;
    my $filename = $self->filename($cil);

    return unless -e $filename;

    open my $fh, '<', $filename or
        die "error opening $filename for read: $!";

    while (<$fh>)
    {
        chomp;
        my @fields = split /\t/, $_, 0+@FILE_FIELDS;
        my %record = map { $FILE_FIELDS[$_] => $fields[$_] } (0 .. @FILE_FIELDS-1);
        push @{ $self->{data}{Worked} }, \%record;
    }

    close $fh;
}

sub commit
{
    my ($self, $cil) = @_;
    my $filename = $self->filename( $cil );
    my $tempfile = $self->tempfile( $cil );

    $self->write( $tempfile );

    rename $tempfile => $filename or
        die "rename error for $tempfile => $filename: $!";
}

sub write
{
    my ($self, $filename) = @_;

    open my $fh, '>', $filename or
        die "error opening $filename for write: $!";

    for my $record (@{ $self->{data}{Worked} })
    {
        print $fh join "\t" => @{$record}{@FILE_FIELDS};
        print $fh "\n";
    }

    close $fh or
        die "error closing $filename after write: $!";
}

sub name
{
    return shift->{data}{ShortName};
}

sub filename
{
    my ($self, $cil) = @_;

    return sprintf "%s/t_%s.cil" =>
        $cil->IssueDir, $self->name;
}

sub tempfile
{
    my ($self, $cil) = @_;
    my $random = join " " => map { ('a' .. 'z')[int rand 26] } (0 .. 8);

    return sprintf "%s/.t_%s.cil.$random" =>
        $cil->IssueDir, $self->{data}{ShortName};
}


1;

