import React from "https://unpkg.com/es-react@latest/dev/react.js";
import ReactDOM from "https://unpkg.com/es-react@latest/dev/react-dom.js";
import PropTypes from "https://unpkg.com/es-react@latest/dev/prop-types.js";
import htm from "https://unpkg.com/htm@latest?module";
const html = htm.bind(React.createElement);

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
