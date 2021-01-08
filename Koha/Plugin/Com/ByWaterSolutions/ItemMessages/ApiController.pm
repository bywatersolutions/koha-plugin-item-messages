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
use Koha::Item::Message;
use Koha::Item::Messages;
use Koha::DateUtils;

use Try::Tiny;

sub list_item_messages {
    my ( $c, $args, $cb ) = @_;

    if ( !Koha::Items->search({ itemnumber => $args->{itemnumber} })->count > 0 ) {
        return $c->$cb( { error => 'Item not found' }, 400 );
    }

    return try {
        my $item_messages = Koha::Item::Messages->search({ itemnumber => $args->{itemnumber} });
        return $c->$cb( $item_messages, 200 );
    }
    catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->$cb( { error => $_->{msg} }, 500 );
        }
        else {
            return $c->$cb( { error => "Something went wrong, check the logs." }, 500 );
        }
    };
}

sub get_item_message {
    my ( $c, $args, $cb ) = @_;

    if ( !Koha::Items->search( { itemnumber => $args->{itemnumber} } )->count > 0 ) {
        return $c->$cb( { error => 'Item not found' }, 400 );
    }

    return try {
        my $item_message
            = Koha::Item::Messages->search(
            { itemnumber => $args->{itemnumber}, item_message_id => $args->{item_message_id} } )
            ->next;
        if ($item_message) {
            return $c->$cb( $item_message, 200 );
        }
        else {
            return $c->$cb( { error => 'Item message not found' }, 400 );
        }
    }
    catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->$cb( { error => $_->{msg} }, 500 );
        }
        else {
            return $c->$cb( { error => "Something went wrong, check the logs." }, 500 );
        }
    };
}

sub add_item_message {
    my ( $c, $args, $cb ) = @_;

    my $item_message = Koha::Item::Message->new( $args->{body} );
    $item_message->itemnumber( $args->{itemnumber} );

    return try {
        $item_message->store();
        $item_message = Koha::Item::Messages->find( $item_message->id );
        return $c->$cb( $item_message, 200 );
    }
    catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->$cb( { error => $_->msg }, 500 );
        }
        else {
            return $c->$cb( { error => "Something went wrong, check the logs." }, 500 );
        }
    };
}

sub update_item_message {
    my ( $c, $args, $cb ) = @_;

    my $item_message;

    return try {
        $item_message
            = Koha::Item::Messages->search(
            { itemnumber => $args->{itemnumber}, item_message_id => $args->{item_message_id} } )
            ->next;
        $item_message->set( $args->{body} );
        $item_message->store();
        return $c->$cb( $item_message, 200 );
    }
    catch {
        if ( not defined $item_message ) {
            return $c->$cb( { error => "Item message not found" }, 404 );
        }
        elsif ( $_->isa('Koha::Exceptions::Object') ) {
            return $c->$cb( { error => $_->message }, 500 );
        }
        else {
            return $c->$cb( { error => "Something went wrong, check the logs." }, 500 );
        }
    };

}

sub delete_item_message {
    my ( $c, $args, $cb ) = @_;

    my $item_message;

    return try {
        $item_message = Koha::Item::Messages->search(
            { itemnumber => $args->{itemnumber}, item_message_id => $args->{item_message_id} } );
        $item_message->delete;
        return $c->$cb( q{}, 200 );
    }
    catch {
        if ( not defined $item_message ) {
            return $c->$cb( { error => "Item message not found" }, 404 );
        }
        elsif ( $_->isa('DBIx::Class::Exception') ) {
            return $c->$cb( { error => $_->msg }, 500 );
        }
        else {
            return $c->$cb( { error => "Something went wrong, check the logs." }, 500 );
        }
    };
}

1;
