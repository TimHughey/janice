function pageReady( jQuery ) {
    // Code to run when the document is ready.
    var noDeviceTable = $('#noDeviceTable').DataTable( {
      "ajax": "mcp/api/detail/alias-only",
      "deferRender": true,
      "columns": [
        {"data": "id"},
        {"data": "friendly_name"},
        {"data": "device"},
        {"data": "description"},
        {"data": "last_seen_secs"},
        {"data": "last_seen_at"}
      ]
    });

    var switchTable = $('#switchesTable').DataTable( {
      "ajax": "mcp/api/detail/switches",
      "deferRender": true,
      "columns": [
        {"data": "id"},
        {"data": "friendly_name"},
        {"data": "device"},
        {"data": "enabled"},
        {"data": "description"},
        {"data": "dev_latency"},
        {"data": "last_cmd_secs"},
        {"data": "last_seen_secs"}
      ]
    });

    var switchTable = $('#sensorsTable').DataTable( {
      "ajax": "mcp/api/detail/sensors",
      "deferRender": true,
      "columns": [
        {"data": "id"},
        {"data": "friendly_name"},
        {"data": "device"},
        {"data": "description"},
        {"data": "last_seen_secs"},
        {"data": "reading_secs"},
        {"data": "celsius"}
      ]
    });
}

function pageFullyLoaded() {
  setTimeout(function(){
        var masthead = $('#mastheadText');
        masthead.removeClass('text-muted').addClass('text-ready');
    }, 10);
}

// var dt = require( 'datatables.net' )();
// $().DataTable();


$(document).ready( pageReady );

$( window ).on( "load", pageFullyLoaded );

// $(function() {
//     $('.lazy').Lazy({
//       noDeviceTabLoad: function(element) {
//           var data = $.get("mcp/detail/nodevice");
//           element.html(data);
//         }});
//     });

$( "#collapseNoDevice" ).on('show.bs.collapse', function(event) {
    $('#noDeviceTable').DataTable().ajax.reload();
      // setTimeout(function(){ $('#collapseNoDevice').collapse('hide'); }, 3000);
});

$( "#collapseSwitches" ).on('show.bs.collapse', function(event) {
  $('#switchesTable').DataTable().ajax.reload();
});

$( "#collapseSensors" ).on('show.bs.collapse', function(event) {
  $('#senorsTable').DataTable().ajax.reload();
});

// DEPRECATED -- left as a future example
//   jQuery.get( "mcp/detail/nodevice", function( data ) {
//     $( "#noDeviceCard" ).html( data );
//   });
// });
