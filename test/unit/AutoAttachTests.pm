# Test cases:
# 1) Autoattach = off. Save a topic referring to an attachmentMissing that does not exist.
# 2) Add attachmentAdded into the attachment area for that topic, circumventing Foswiki
# 3) Turn autoattach = on. Ask for the list of attachments. attachmentAdded should appear. attachmentMissing should not.

package AutoAttachTests;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Foswiki::Func();
use Error qw( :try );
use Foswiki::UI::Save;
use Foswiki::OopsException;
use Devel::Symdump;

sub new {
    my $this = shift()->SUPER::new( 'AutoAttach', @_ );
    return $this;
}

my %cfg;

use Data::Dumper;

sub set_up_topic {
    my $this = shift;

    # Create topic
    my $topic = shift;
    my $text  = "hi";

    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    $topicObject->text($text);
    $topicObject->save();
    $topicObject->finish();
}

# We create a topic with a missing attachment
# This attachment should be now omitted from the resulting output
sub addMissingAttachment {
    my $this    = shift;
    my $topic   = shift;
    my $file    = shift;
    my $comment = shift;

    $this->assert( $this->{session}->topicExists( $this->{test_web}, $topic ) );

    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $topic );

    $topicObject->putKeyed(
        'FILEATTACHMENT',
        {
            name    => $file,
            version => '',
            path    => $file,
            size    => 2000000,
            date    => 2000000,
            user    => "ProjectContributor",
            comment => $comment,
            attr    => ''
        }
    );
    $topicObject->save();
}

# We create a 3 more attachment entries:
# one (afile.txt) that should be detected and
# another two (_afile.txt and _hiddenDirectoryForPlugins) that should not

sub sneakAttachmentsAddedToTopic {
    my $this = shift;
    my ( $topic, @filenames ) = @_;
    my $dir = $Foswiki::cfg{PubDir};
    $dir = "$dir/$this->{test_web}/$topic";

    #print STDERR "DEBUG: dir=$dir\n";

    foreach my $file (@filenames) {
        touchFile("$dir/$file");
    }

    mkdir $dir . '/_hiddenDirectoryForPlugins';
}

sub touchFile {
    my $filename = shift;
    open( FILE, ">$filename" );
    print FILE "Test attachment $filename\n";
    close(FILE);
}

sub test_no_autoattach {
}

sub test_autoattach {

    $Foswiki::cfg{RCS}{AutoAttachPubFiles} = 1;

    my $this  = shift;
    my $topic = "UnitTest1";
    $this->set_up_topic($topic);
    $this->verify_normal_attachment( $topic, "afile.txt" );
    $this->verify_normal_attachment( $topic, "bfile.txt" );

    $this->addMissingAttachment( $topic, 'bogusAttachment.txt',
        "I'm a figment of Foswiki's imagination" );
    $this->addMissingAttachment( $topic, 'ressurectedComment.txt',
        'ressurected attachment comment' );
    $this->sneakAttachmentsAddedToTopic( $topic, 'sneakedfile1.txt',
        'sneakedfile2.txt', 'commavfilesshouldbeignored2.txt,v',
        '_hiddenAttachment.txt', 'ressurectedComment.txt' );

    my ( $meta, $text ) = $this->simulate_view( $this->{test_web}, $topic );
    my @attachments = $meta->find('FILEATTACHMENT');

    #    printAttachments(@attachments); # leave as comment unless debugging

    $this->foundAttachmentsMustBeGettable( $meta, @attachments );

    # ASSERT the commavfile should not be found, but should be gettable.

    # Our attachment correctly listed in meta data still exists:
    #    my $afileAttributes = $meta->get('FILEATTACHMENT', "afile.txt");
    #    $this->assert_not_null($afileAttributes);

    # Our added files now exist:
    my $sneakedfile1Attributes =
      $meta->get( 'FILEATTACHMENT', "sneakedfile1.txt" );
    my $sneakedfile2Attributes =
      $meta->get( 'FILEATTACHMENT', "sneakedfile2.txt" );
    $this->assert_not_null($sneakedfile1Attributes);
    $this->assert_not_null($sneakedfile2Attributes);

    # We have deleted the faulty bogus reference:
    my $bogusAttachmentAttributes =
      $meta->get( 'FILEATTACHMENT', "bogusAttachment.txt" );
    $this->assert_null($bogusAttachmentAttributes);

# And commav files are still gettable (we check earlier that it is not listable).
    my $commavfilesshouldbeignoredAttributes =
      $meta->get( 'FILEATTACHMENT', "commavfilesshouldbeignored2.txt,v" );
    $this->assert_null($commavfilesshouldbeignoredAttributes);

}

sub foundAttachmentsMustBeGettable {
    my ( $this, $meta, @attachments ) = @_;

    foreach my $attachment (@attachments) {
        my $attachmentName = $attachment->{name};

        #print "Testing file exists ".$attachmentName.": ";
        my $attachmentAttributes =
          $meta->get( 'FILEATTACHMENT', $attachmentName );
        $this->assert_not_null($attachmentAttributes);

        # print Dumper($attachmentAttributes)."\n";

        if ( $attachmentName eq "commavfilesshouldbeignored2.txt,v" ) {
            die
"commavfilesshouldbeignored2.txt,v should not be returned in the listing";
        }
    }
}

# needed for debugging (see above)
sub printAttachments {
    my (@attachments) = @_;
    print "\n\n-------ATTACHMENTS--------\n";
    foreach my $attachment (@attachments) {
        print "Attachment found: " . Dumper($attachment) . "\n";
    }
}

sub verify_normal_attachment {
    my $this = shift;

    my $topic      = shift;
    my $attachment = shift;

    $this->assert( $this->{session}->topicExists( $this->{test_web}, $topic ) );

    open( FILE, ">$Foswiki::cfg{TempfileDir}/$attachment" );
    print FILE "Test attachment\n";
    close(FILE);

    my $saveCmd         = "";
    my $doNotLogChanges = 0;
    my $doUnlock        = 1;

    my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    $meta->attach(
        name    => $attachment,
        file    => "$TWiki::cfg{TempfileDir}/$attachment",
        comment => 'comment 1'
    );

    unlink "$Foswiki::cfg{TempfileDir}/$attachment";

    # Check revision number
    my $rev = $meta->getLatestRev($attachment);
    $this->assert_num_equals( 1, $rev );

}

sub simulate_view {
    my ( $this, $web, $topic ) = @_;

    my $oldWebName   = $this->{session}->{webName};
    my $oldTopicName = $this->{session}->{topicName};

    $this->{session}->{webName}   = $web;
    $this->{session}->{topicName} = $topic;

    my ($meta) = Foswiki::Func::readTopic( $web, $topic );

    $this->{session}->{webName}   = $oldWebName;
    $this->{session}->{topicName} = $oldTopicName;

    return $meta;
}

1;
