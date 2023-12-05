package Koha::Plugin::Com::ByWaterSolutions::ItemMessages::ApiController;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use Koha::Items;
use Koha::DateUtils;

use Try::Tiny;

sub list_item_messages {
    my $c = shift->openapi->valid_input or return;

    my $itemnumber = $c->validation->param('item_id');

    if ( !Koha::Items->search({ itemnumber => $itemnumber })->count > 0 ) {
        return $c->render(
            status => 400,
            openapi => { error => 'Item not found' }
        );
    }

    return try {
        my $item_messages = C4::Context->dbh->selectall_arrayref("SELECT * FROM item_messages WHERE itemnumber = ?", { Slice => {} }, $itemnumber);
        return $c->render( status => 200, json => $item_messages );
    }
    catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->render(
                status => 500,
                openapi => { error => $_->{msg} }
            );
        }
        else {
            return $c->render(
                status => 500,
                openapi => { error => "Something went wrong, check the logs." }
            );
        }
    };
}

sub get_item_message {
    my $c = shift->openapi->valid_input or return;

    my $itemnumber = $c->validation->param('item_id');
    my $item_message_id = $c->validation->param('item_message_id');

    my $item_messages = C4::Context->dbh->selectall_arrayref("SELECT * FROM item_messages WHERE itemnumber = ?", { Slice => {} }, $itemnumber);
    unless (@$item_messages) {
        return $c->render(
            status => 400,
            openapi => { error => "Item not found" }
        );
    }

    return try {

    my $item_messages = C4::Context->dbh->selectall_arrayref("SELECT * FROM item_messages WHERE itemnumber = ?", { Slice => {} }, $itemnumber);
        my $item_message = C4::Context->dbh->selectrow_hashref("SELECT * FROM item_messages WHERE itemnumber = ? AND item_message_id = ?", undef, $itemnumber, $item_message_id );
        if ($item_message) {
            return $c->render( status => 200, json => $item_message );
        }
        else {
            return $c->render( status => 400, openapi => { error => 'Item message not found' } );
        }
    }
    catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->render( status => 500, openapi => { error => $_->{msg} } );
        }
        else {
            return $c->render( status => 500, openapi => { error => "Something went wrong, check the logs." } );
        }
    };
}

sub add_item_message {
    my $c = shift->openapi->valid_input or return;

    my $itemnumber = $c->validation->param('item_id');
    my $body       = $c->validation->param('body');

    my $dbh = C4::Context->dbh;

    return try {

        $dbh->do("INSERT INTO item_messages VALUES (?,?,?,?,NOW())", undef, undef, $itemnumber, $body->{type}, $body->{message} );
        my $item_message_id = $dbh->{'mysql_insertid'};
        my $item_message = $dbh->selectrow_hashref("SELECT * FROM item_messages WHERE itemnumber = ? AND item_message_id = ?", undef, $itemnumber, $item_message_id );
        
        return $c->render( status => 200, json => $item_message );
    }
    catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->render( status => 500, openapi => { error => $_->{msg} } );
        }
        else {
            return $c->render( status => 500, openapi => { error => "Something went wrong, check the logs." } );
        }
    };
}

sub update_item_message {
    my $c = shift->openapi->valid_input or return;

    my $itemnumber      = $c->validation->param('item_id');
    my $item_message_id = $c->validation->param('item_message_id');
    my $body            = $c->validation->param('body');

    my $dbh = C4::Context->dbh;

    return try {
        $dbh->do("UPDATE item_messages SET type = ?, message = ? WHERE itemnumber = ? AND item_message_id = ?", undef, $body->{type}, $body->{message}, $itemnumber, $item_message_id );
        my $item_message = C4::Context->dbh->selectrow_hashref("SELECT * FROM item_messages WHERE itemnumber = ? AND item_message_id = ?", undef, $itemnumber, $item_message_id );
        return $c->render( status => 200, json => $item_message );
    }
    catch {
        return $c->render( status => 500, openapi => { error => "Something went wrong, check the logs." } );
    };

}

sub delete_item_message {
    my $c = shift->openapi->valid_input or return;

    my $itemnumber      = $c->validation->param('item_id');
    my $item_message_id = $c->validation->param('item_message_id');

    my $item_message;

    my $dbh = C4::Context->dbh;

    return try {
        my $item_message = $dbh->selectrow_hashref("SELECT * FROM item_messages WHERE itemnumber = ? AND item_message_id = ?", undef, $itemnumber, $item_message_id );
        $dbh->do("DELETE FROM item_messages WHERE itemnumber = ? AND item_message_id = ?", undef, $itemnumber, $item_message_id );
        return $c->render( status => 200, openapi => $item_message );
    }
    catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->render( status => 500, openapi => { error => $_->{msg} } );
        }
        else {
            return $c->render( status => 500, openapi => { error => "Something went wrong, check the logs." } );
        }
    };
}

sub get_item_message_types {
    my $c = shift->openapi->valid_input or return;

    my $authorised_values = Koha::AuthorisedValues->search({ category => 'ITEM_MESSAGE_TYPE' })->unblessed;

    return $c->render( status => 200, openapi => $authorised_values );
}

1;
