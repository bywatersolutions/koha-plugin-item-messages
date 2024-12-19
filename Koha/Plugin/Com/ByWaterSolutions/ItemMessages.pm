package Koha::Plugin::Com::ByWaterSolutions::ItemMessages;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use C4::Auth;
use C4::Context;
use Koha::AuthorisedValues;
use Koha::DateUtils qw(dt_from_string);
use Koha::Schema;
use C4::Circulation qw( barcodedecode );

use Module::Metadata;
use Mojo::JSON qw(decode_json to_json);

our $VERSION = "{VERSION}";
our $MINIMUM_VERSION = "{MINIMUM_VERSION}";

our $metadata = {
    name            => 'Item Messages Plugin',
    author          => 'Kyle M Hall',
    date_authored   => '2021-01-05',
    date_updated    => "1900-01-01",
    minimum_version => $MINIMUM_VERSION,
    maximum_version => undef,
    version         => $VERSION,
    description     => 'A plugin for Koha to add and edit messages related to a specific item.',
};

sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}


## If your plugin needs to add some CSS to the staff intranet, you'll want
## to return that CSS here. Don't forget to wrap your CSS in <style>
## tags. By not adding them automatically for you, you'll have a chance
## to include external CSS files as well!
sub intranet_head {
    my ( $self ) = @_;

    return q||;
}

## If your plugin needs to add some javascript in the staff intranet, you'll want
## to return that javascript here. Don't forget to wrap your javascript in
## <script> tags. By not adding them automatically for you, you'll have a
## chance to include other javascript files if necessary.
sub intranet_js {
    my ( $self ) = @_;

    return q|
        <script type="module" src="/api/v1/contrib/item_messages/static/static_files/intranet.js"></script>
    |;
}

sub install() {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;

    $dbh->do(q{
        CREATE TABLE `item_messages` (
            `item_message_id` INT( 11 ) NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `itemnumber` INT( 11 ) NOT NULL,
            `type` VARCHAR( 80 ) NULL, -- ITEM_MESSAGE authorised value
            `message` TEXT NOT NULL,
            `created_on` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX (  `itemnumber` ),
            CONSTRAINT `message_item_fk` FOREIGN KEY (itemnumber) REFERENCES items (itemnumber) ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    });
}

sub upgrade {
    my ( $self, $args ) = @_;

    my $dt = dt_from_string();
    $self->store_data( { last_upgraded => $dt->ymd('-') . ' ' . $dt->hms(':') } );

    return 1;
}

sub uninstall() {
    my ( $self, $args ) = @_;

    return C4::Context->dbh->do("DROP TABLE IF EXISTS item_messages");
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template({ file => 'configure.tt' });

        ## Grab the values we already have for our settings, if any exist
        $template->param(
            auto_delete_lost => $self->retrieve_data('auto_delete_lost'),
        );

        $self->output_html( $template->output() );
    }
    else {
        $self->store_data(
            {
                auto_delete_lost => $cgi->param('auto_delete_lost'),
            }
        );
        $self->go_home();
    }
}

sub tool {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};
    if ( $cgi->param('update') || $cgi->param('delete') ) {
        $self->tool_step3();
    }
    elsif ( $cgi->param('submitted') ) {
        $self->tool_step2();
    } else {
        $self->tool_step1();
    }

}

sub tool_step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'tool-step1.tt' });
    
    $self->output_html( $template->output() );
}

sub tool_step2 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'tool-step2.tt' });
    
    my $uploadbarcodes = $cgi->upload('uploadbarcodes');
    my @barcodes;
    my @uploadedbarcodes;

    if ( $uploadbarcodes && length($uploadbarcodes) > 0 ) {
        binmode($uploadbarcodes, ":encoding(UTF-8)");
        my $split_chars = C4::Context->preference('BarcodeSeparators');
        while (my $barcode=<$uploadbarcodes>) {
            chomp $barcode;
            push @uploadedbarcodes, grep { /\S/ } split( /[$split_chars]/, $barcode );
        }
    } else {
        warn 'NO UPLOADED BARCODES';
    }

    for my $barcode (@uploadedbarcodes) {
        next unless $barcode;

        $barcode = barcodedecode($barcode);

        push @barcodes,$barcode;
    }

    my @items_rs = Koha::Items->search(
        { barcode => { -in => \@barcodes } },
        {
            join     => 'biblio',
            prefetch => 'biblio',
        }
    )->as_list;

    my %items_data;  # Hash to store item and biblio information

    foreach my $item (@items_rs) {
        my $biblio = $item->biblio;  # Access the prefetched biblio relation
        $items_data{$item->itemnumber} = {
            itemnumber  => $item->itemnumber,
            barcode  => $item->barcode,
            title    => $biblio->title,
            biblio   => $biblio,
            messages => [],   # Placeholder for item_messages.message
            type     => '',   # Placeholder for item_messages.type
        };
    }

    if (%items_data) {
        my @itemnumbers = keys %items_data;
        my $dbh = C4::Context->dbh;
        my $placeholders = join(',', ('?') x @itemnumbers);
        my $query = qq{
            SELECT itemnumber, message, type, item_message_id
            FROM item_messages
            WHERE itemnumber IN ($placeholders)
        };

        my $sth = $dbh->prepare($query);
        $sth->execute(@itemnumbers);

        while (my $row = $sth->fetchrow_hashref) {
            my $itemnumber = $row->{itemnumber};
            if (exists $items_data{$itemnumber}) {
                push @{$items_data{$itemnumber}->{messages}}, {
                    item_message_id => $row->{item_message_id},
                    message => $row->{message},
                    type    => $row->{type},
                };
            }
        }
    }

    my @scanned_items = values %items_data;

    $template->param(
        scanned_items => \@scanned_items,
    );   

    $self->output_html( $template->output() );
}

sub tool_step3 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'tool-step3.tt' });
    
    my @itemnumbers = $cgi->param('itemnumber');
    my $action = $cgi->param('action');
    my $type = $cgi->param('type');
    my $delete_type = $cgi->param('delete_type');
    my $dbh = C4::Context->dbh;
    my @updated_items;

    if ( $action eq 'update' ) {
        my $new_message = $cgi->param('new_message');
        my $new_type = $cgi->param('new_type');

        unless ($new_type && $new_message ) {
            warn "No message or message type provided!";
            return;
        }

        my $placeholders = join(',', ('?') x scalar(@itemnumbers));

        my $delete_query = qq{
            DELETE FROM  item_messages
            WHERE itemnumber IN ( $placeholders )
        };

        my $delete_sth = $dbh->prepare($delete_query);
        $delete_sth->execute(@itemnumbers);

        my $query = qq{
            INSERT  INTO item_messages (itemnumber, message, type)
            VALUES (?, ?, ?)
        };

        my $sth = $dbh->prepare($query);
        foreach my $itemnumber (@itemnumbers) {
            $sth->execute($itemnumber, $new_message, $new_type);
        }
        
        $sth->finish;

    } elsif ( $action eq 'delete' )  {
        unless (@itemnumbers) {
            warn "No itemnumbers provided!";
            return;
        }

        my $placeholders = join(',', ('?') x scalar(@itemnumbers));
        my $select_query = qq{
            SELECT im.item_message_id, im.itemnumber, im.message AS old_message, im.type,
                   i.barcode, b.title
            FROM item_messages im
            JOIN items i ON im.itemnumber = i.itemnumber
            LEFT JOIN biblio b ON i.biblionumber = b.biblionumber
            WHERE im.type = ?
              AND i.itemnumber IN ($placeholders)
        };

        my $select_sth = $dbh->prepare($select_query);
        $select_sth->execute($delete_type, @itemnumbers);

        while (my $row = $select_sth->fetchrow_hashref) {
            next unless $row;

            push @updated_items, {
                item_message_id => $row->{item_message_id},
                itemnumber      => $row->{itemnumber},
                barcode         => $row->{barcode},
                title           => $row->{title},
                message         => $row->{message},
                type            => $row->{type},
            };
        }

        $select_sth->finish;
        my $count = scalar @updated_items;

        my $query = qq{
            DELETE FROM  item_messages
            WHERE type = ?
            AND itemnumber IN ( $placeholders )
        };

        my $sth = $dbh->prepare($query);
        $sth->execute($delete_type, @itemnumbers);
        $template->param(
            action        => $action,
            updated_count => $count,
            updated_items => \@updated_items,
        );
    }

    $self->output_html( $template->output() );
}

## API methods
# If your plugin implements API routes, then the 'api_routes' method needs
# to be implemented, returning valid OpenAPI 2.0 paths serialized as a hashref.
# It is a good practice to actually write OpenAPI 2.0 path specs in JSON on the
# plugin and read it here. This allows to use the spec for mainline Koha later,
# thus making this a good prototyping tool.

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('openapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub api_namespace {
    my ( $self ) = @_;
    
    return 'item_messages';
}

sub static_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('staticapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub after_item_action {
     my ($self, $params) = @_;

     my $auto_delete_lost = $self->retrieve_data('auto_delete_lost');
     return unless $auto_delete_lost eq 'on';

     my $action = $params->{action};
     my $item = $params->{item};
     my $dbh = C4::Context->dbh;
     #continue only if the action is modify and the lost status is 0
     if ( $action eq 'modify' && $item->itemlost == 0 ) {
        my $itemnumber = $params->{item_id};

        my $sth = $dbh->prepare(q{
            DELETE FROM item_messages
            WHERE
                itemnumber = ?
        });
        $sth->execute($itemnumber);
     };

}

1;
