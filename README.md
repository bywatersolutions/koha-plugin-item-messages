# Item Messages plugin for Koha
A plugin for Koha to add and edit messages related to a specific item. These messages or notes can be added to the item through the "more detail" tab. Notes/Messages can be a free text or alternatively can be connected to an authorized value, ITEM_MESSAGE_TYPE. The messages/notes that are added to the item will only be visible via the "more detail" item tab as well as through reports.

## Setup
* Download and install the plugin
* Restart Plack, this is necessary to add the new REST API endpoints
* Create new Authorised Value category ITEM_MESSAGE_TYPE

The ITEM_MESSAGE_TYPE authorised value category will define the different types of messages items may have.

If you would like to have a set up option for a given message type,
instead of a free text field, you may add a list of pipe (|) delimeted
options in the OPAC description for that authorised value.

Once this setup is complete, go to a title within the catalog.  Choose the "Item" tab on the left-hand side of the view.  This is will open up more detail of the item itself.  There will be a new area to allow for these notes/messages to be added to the item, found below the barcode field. Any number of notes/messages can be added to the item.

## Database Structure

This plugin creates a new table `item_messages` containing the following columns:
* `item_message_id` - iternal id for this message, auto increments
* `itemnumber`- foreign key to the items table
* `type` - ITEM_MESSAGE authorised value
* `message` - the actualy value for this message
* `created_on` - a timestamp for this message

  
