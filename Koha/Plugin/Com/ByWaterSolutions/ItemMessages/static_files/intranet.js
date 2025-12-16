import React from "https://unpkg.com/es-react@latest/dev/react.js";
import ReactDOM from "https://unpkg.com/es-react@latest/dev/react-dom.js";
import PropTypes from "https://unpkg.com/es-react@latest/dev/prop-types.js";
import htm from "https://unpkg.com/htm@latest?module";
const html = htm.bind(React.createElement);

var CANCEL = _("Cancel");
var ADD_MESSAGE = _("Add message");
var ARE_YOU_SURE = _("Are you sure you want to delete the following message: ");

var authorised_values;
var av_descriptions = [];
$(document).ready(function() {
    if (window.location.href.indexOf("catalogue/moredetail.pl") > -1) {
        const promise1 = $.ajax({
            dataType: "json",
            url: "/api/v1/contrib/item_messages/authorised_values",
            success: function(avs) {
                authorised_values = avs;
                for (var i = 0; i < authorised_values.length; i++) {
                    var av = authorised_values[i];
                    av_descriptions[av.authorised_value] = av;
                }
            }
        });

        Promise.all([promise1]).then(() => {
            const itemElements = document.querySelectorAll("#catalogue_detail_biblio h3[id^=item]");
            
            const observer = new IntersectionObserver((entries, observer) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        const itemElement = entry.target;
                        const itemnumber = itemElement.id.replace('item', '');
                        
                        // Stop observing this element since we're loading its messages now
                        observer.unobserve(itemElement);
                        
                        // Create the container for messages
                        const container = document.createElement('div');
                        container.className = 'listgroup';
                        container.innerHTML = `<div id="item-messages-${itemnumber}" class="item-messages"></div>`;
                        
                        // Insert the container before the next sibling of the item header
                        itemElement.parentNode.insertBefore(container, itemElement.nextSibling);
                        
                        // Load messages for this item
                        $.ajax({
                            dataType: "json",
                            url: `/api/v1/contrib/item_messages/items/${itemnumber}/messages`,
                            success: function(messages) {
                                ReactDOM.render(
                                    html `<${ItemMessages} itemnumber=${itemnumber} messages=${messages || []} />`,
                                    document.getElementById(`item-messages-${itemnumber}`)
                                );
                            }
                        });
                    }
                });
            }, {
                root: null, // viewport
                rootMargin: '0px',
                threshold: 0.1 // Trigger when at least 10% of the element is visible
            });

            // Start observing each item element
            itemElements.forEach(itemElement => {
                observer.observe(itemElement);
            });
        });
    }
});

class ItemMessages extends React.Component {
    constructor(props, context) {
        super(props, context);

        this.state = {
            itemnumber: props.itemnumber,
            messages: props.messages || []
        };
    }

    addMessage = (message) => {
        this.setState(function(state) {
            var newData = state.messages.slice();
            newData.push(message);
            return {
                messages: newData
            };
        });
    }

    removeMessage = (index) => {
        var message = this.state.messages[index];
        var itemMessage = this;
        $.ajax({
            url: '/api/v1/contrib/item_messages/items/' + message.itemnumber + '/messages/' + message.item_message_id,
            type: 'DELETE',
            success: function() {
                itemMessage.setState(function(state) {
                    var newData = state.messages.slice();
                    newData.splice(index, 1);
                    return {
                        messages: newData
                    };
                });
            }
        });
    }

    render = () => {
        var item_messages = this;
        return html `<div className="listgroup">
                    <h4>Messages</h4>
                    <ol className="bibliodetails">
                        ${this.state.messages.map(function(message, index) {
                            return html`<${ItemMessage} key=${message.item_message_id} message=${message} index=${index} onRemove=${item_messages.removeMessage} />`
                        })}
                        <${ItemMessageCreator} itemnumber=${this.props.itemnumber} onAdd=${item_messages.addMessage}/>
                    </ol>
                </div>`;
    }
}

class ItemMessage extends React.Component {
    removeMessage = () => {
        if (confirm(ARE_YOU_SURE + this.props.message.message)) {
            this.props.onRemove(this.props.index);
        }
    }

    render = () => {
        return html `<li>
                    <span className="label">
                        <span className="badge text-bg-success">
                            ${av_descriptions[this.props.message.type].lib}
                        </span>
                    </span>

                    <span style=${{margin: ".5em"}}>${this.props.message.message}</span>

				    <button href="#" onClick=${this.removeMessage}><i className="fa fa-trash"></i></button>
                </li>`;
    }
}

class ItemMessageCreator extends React.Component {
    constructor(props, context) {
        super(props, context);

        this.state = {
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
            url: '/api/v1/contrib/item_messages/items/' + this.props.itemnumber + '/messages',
            data: JSON.stringify(item_message),
            success: function(data) {
                self.cancelMessage();
                self.props.onAdd(data);
            },
            error: function(xhr, ajaxOptions, thrownError) {
                console.log(xhr.responseText);
                console.log(thrownError);
            },
        });
    }

    cancelMessage = () => {
        this.setState({
            message: "",
            type: authorised_values[0].authorised_value,
        });
        return false;
    }

    handleTypeChange = (e) => {
        this.setState({
            type: e.target.value
        });
    }

    handleContentChange = (e) => {
        this.setState({
            message: e.target.value
        });
    }

    render = () => {
        // build the 'type' pulldown options from the list authorised values
        var options = [];
        for (var i = 0; i < authorised_values.length; i++) {
            var av = authorised_values[i];
            options.push(
                html `<option key=${i} value=${av.authorised_value}>${av.lib}</option>`
            );
        }

        // opac_opac may have a list of pipe separated values
        // if it does, we create a pulldown of those values
        // instead of a free text field input
        let selected_av = av_descriptions[this.state.type];
        let lib_opac = selected_av.lib_opac;
        let av_options = [];
        if (lib_opac) av_options = lib_opac.split('|');

        let pulldown_or_text;
        if (lib_opac) {
            pulldown_or_text = html `
                <select style=${{margin: ".5em"}}
                        className="input-xlarge"
                        value=${this.state.message}
                        onChange=${this.handleContentChange}
                        style=${{width: "15em", margin: ".5em"}}
                >
                    ${ av_options.map( (av) => html`<option key=${av} value=${av}>${av}</option>` ) }
                </select>`;
        } else {
            pulldown_or_text = html `<input style=${{width: "15em", margin: ".5em"}} className="input-xlarge" type="text" value=${this.state.message} onChange=${this.handleContentChange} />`;
        }

        return html `<li>
                    <select value=${this.state.type} onChange=${this.handleTypeChange}>
                        ${options}
                    </select>
                    ${pulldown_or_text}
                    <button className="btn btn-primary btn-xs" onClick=${this.addMessage}>
                        <i className="fa fa-plus-circle"></i> ${ADD_MESSAGE}
                    </button>
                </li>`;
    }
}
