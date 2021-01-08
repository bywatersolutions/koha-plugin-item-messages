package Koha::Plugin::Com::ByWaterSolutions::ItemMessages;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use C4::Auth;
use C4::Context;
use Koha::AuthorisedValues;
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

    my $authorised_values = Koha::AuthorisedValues->search({ category => 'ITEM_MESSAGE_TYPE' })->unblessed;
    my $av_json = to_json( $authorised_values );
    warn "JSON: " . Data::Dumper::Dumper( $av_json );

    return q|<script type="module">
import React from "https://unpkg.com/es-react@latest/dev/react.js";
import ReactDOM from "https://unpkg.com/es-react@latest/dev/react-dom.js";
import PropTypes from "https://unpkg.com/es-react@latest/dev/prop-types.js";
import htm from "https://unpkg.com/htm@latest?module";
const html = htm.bind(React.createElement);

var authorised_values = | . $av_json . q|;
var item_messages = "[% To.json( item_messages ) %]";
var CANCEL = _("Cancel");
var ADD_MESSAGE = _("Add message");
var ARE_YOU_SURE = _("Are you sure you want to delete the following message: ");

var av_descriptions = [];
$( document ).ready(function() {
    for (var i = 0; i < authorised_values.length; i++) {
        var av = authorised_values[i];
        av_descriptions[av.authorised_value] = av.lib;
    }

//    $('.item-messages').each(function() {
//        var itemnumber = parseInt( $(this).attr('id').split('item-messages-')[1] );
//        ReactDOM.render(
//            <ItemMessages itemnumber={itemnumber} messages={item_messages[itemnumber]}/>,
//            this
//        );
//    });
});

class ItemMessages extends React.Component {
    getInitialState = () => {
        return { messages: this.props.messages };
    }

    addMessage = (message) => {
        this.setState(function(state) {
            var newData = state.messages.slice();
            newData.push( message );
            return {messages: newData};
        });
    }

    removeMessage = (index) => {
        var message = this.state.messages[index];
        var itemMessage = this;
        $.ajax({
            url: '/api/v1/items/' + message.itemnumber + '/messages/' + message.item_message_id,
            type: 'DELETE',
            success: function( result ) {
                itemMessage.setState(function(state) {
                    var newData = state.messages.slice();
                    newData.splice(index, 1);
                    return {messages: newData};
                });
            }
        });
    }

    render = () => {
        var item_messages = this;
        return  html`<div className="listgroup">
                    <h4>Messages</h4>
                    <ol className="bibliodetails">
                        ${this.state.messages.map(function(message, index) {
                            return html`<ItemMessage key=${message.item_message_id} message=${message} index=${index} onRemove=${item_messages.removeMessage} />`
                        })}
                        <ItemMessageCreator itemnumber=${this.props.itemnumber} onAdd=${item_messages.addMessage}/>
                    </ol>
                </div>`;
    }
}

class ItemMessage extends React.Component {
    removeMessage = () => {
        if ( confirm( ARE_YOU_SURE + this.props.message.message ) ) {
            this.props.onRemove(this.props.index);
        }
    }

    render = () => {
        return  html`<li>
                    <span className="label">
                        <i className="fa fa-minus-circle" onClick={this.removeMessage}></i>
                        {av_descriptions[this.props.message.type]}
                    </span>
                    {this.props.message.message}
                </li>`;
    }
}

class ItemMessageCreator extends React.Component {
    getInitialState = () => {
        return {
            message: "",
            type: authorised_values[0].authorised_value,
        };
    }

    addMessage = () => {
        var self = this;
        var item_message = {
            type: this.state.type,
            message: this.state.message,
        };
        $.ajax({
            type: 'POST',
            url: '/api/v1/items/' + this.props.itemnumber + '/messages',
            data: JSON.stringify(item_message),
            success: function(data) {
                self.cancelMessage();
                self.props.onAdd(data);
            },
            error: function (xhr, ajaxOptions, thrownError) {
                console.log(xhr.responseText);
                console.log(thrownError);
            },
        });
    }

    cancelMessage = () => {
        this.setState( this.getInitialState );
        return false;
    }

    handleTypeChange = (e) => {
        this.setState({ type: e.target.value });
    }

    handleContentChange = (e) => {
        this.setState({ message: e.target.value });
    }

    render = () => {
        var options = [];
        for (var i = 0; i < authorised_values.length; i++) {
            var av = authorised_values[i];
            options.push(
                html`<option key=${i} value=${av.authorised_value}>${av.lib}</option>`
            );
        }

        return  html`<li>
                    <span className="label">
                        <select value=${this.state.type} onChange=${this.handleTypeChange}>
                            {options}
                        </select>
                    </span>
                    <input className="input-xlarge" type="text" value=${this.state.message} onChange=${this.handleContentChange} />
                    <button className="submit" onClick=${this.addMessage}>
                        <i className="fa fa-plus-circle"></i>&nbsp;
                        ${ADD_MESSAGE}
                    </button>
                    <a href="javascript:void(0);" onClick=${this.cancelMessage}>${CANCEL}</a>
                </li>`;
      }
}


const App = (props) => {
    return html`<div>Hello World! foo: ${props.foo}</div>`;
};

ReactDOM.render(
    html`<${App} foo=${"bar"} />`,
    document.getElementById("placehold")
);
</script>|;
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
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
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
