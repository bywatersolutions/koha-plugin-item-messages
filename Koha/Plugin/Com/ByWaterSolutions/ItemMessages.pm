package Koha::Plugin::Com::ByWaterSolutions::ItemMessages;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use C4::Auth;
use C4::Context;
use Koha::AuthorisedValues;
use Koha::DateUtils qw(dt_from_string);
use Koha::Schema;

use Module::Metadata;
use Mojo::JSON qw(decode_json to_json);

BEGIN {
    my $path = Module::Metadata->find_module_by_name(__PACKAGE__);
    $path =~ s!\.pm$!/lib!;
    unshift @INC, $path;

    require Koha::Item::Messages;
    require Koha::Item::Message;
    require Koha::Schema::Result::ItemMessage;

    Koha::Schema->register_class(ItemMessage => 'Koha::Schema::Result::ItemMessage');
    Koha::Database->schema({ new => 1 });
}

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

1;
