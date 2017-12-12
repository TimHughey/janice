function pageReady( jQuery ) {
    // Code to run when the document is ready.
    var noDeviceTable = $('#noDeviceTable').DataTable( {
      dom: 'Bfrtip',
      ajax: "mcp/api/detail/alias-only",
      scrollY: '50vh',
      deferRender: true,
      scroller: true,
      columns: [
        {data: "id"},
        {data: "friendly_name"},
        {data: "device"},
        {data: "description"},
        {data: "last_seen_secs"},
        {data: "last_seen_at"}
      ],
      buttons: [
        {
            text: 'Refresh',
            action: function ( e, dt, node, config ) {
                dt.button(0).processing(true);
                dt.ajax.reload();
                dt.button(0).processing(false);
                dt.button(0).text("Refreshed");
                dt.button(0).disable();
                setTimeout(
                  function() { var dt = $('#noDeviceTable').DataTable();
                               dt.button(0).text("Refresh");
                               dt.button(0).enable(); },
                  10000);
            }
        }
      ]
    });

    var switchTable = $('#switchesTable').DataTable( {
      dom: 'Bfrtip',
      "ajax": "mcp/api/detail/switches",
      "scrollY": '50vh',
      "deferRender": true,
      "scroller": true,
      "columns": [
        {"data": "id"},
        {"data": "friendly_name"},
        {"data": "device"},
        {"data": "enabled"},
        {"data": "description"},
        {"data": "dev_latency"},
        {"data": "last_cmd_secs"},
        {"data": "last_seen_secs"}
      ],
      buttons: [
        {
            text: 'Refresh',
            action: function ( e, dt, node, config ) {
                dt.button(0).processing(true);
                dt.ajax.reload();
                dt.button(0).processing(false);
                dt.button(0).text("Refreshed");
                dt.button(0).disable();
                setTimeout(
                  function() { var dt = $('#switchesTable').DataTable();
                               dt.button(0).text("Refresh");
                               dt.button(0).enable(); },
                  10000);
            }
        }
      ]
    });

    var sensorTable = $('#sensorsTable').DataTable( {
      dom: 'Bfrtip',
      "ajax": "mcp/api/detail/sensors",
      "scrollY": '50vh',
      "deferRender": true,
      "scroller": true,
      "columns": [
        {"data": "id"},
        {"data": "friendly_name"},
        {"data": "device"},
        {"data": "description"},
        {"data": "last_seen_secs"},
        {"data": "reading_secs"},
        {"data": "celsius"}
      ],
      buttons: [
        {
            text: 'Refresh',
            action: function ( e, dt, node, config ) {
                dt.button(0).processing(true);
                dt.ajax.reload();
                dt.button(0).processing(false);
                dt.button(0).text("Refreshed");
                dt.button(0).disable();
                setTimeout(
                  function() { var dt = $('#sensorsTable').DataTable();
                               dt.button(0).text("Refresh");
                               dt.button(0).enable(); },
                  10000);
            }
        }
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

$("#collapseNoDevice").on('show.bs.collapse', function(event) {
    $('#noDeviceTable').DataTable().ajax.reload();
      // setTimeout(function(){ $('#collapseNoDevice').collapse('hide'); }, 3000);
});

$("#collapseSwitches").on('show.bs.collapse', function(event) {
  $('#switchesTable').DataTable().ajax.reload();
});

$("#collapseSensors").on('show.bs.collapse', function(event) {
  $('#sensorsTable').DataTable().ajax.reload();
});

// DEPRECATED -- left as a future example
//   jQuery.get( "mcp/detail/nodevice", function( data ) {
//     $( "#noDeviceCard" ).html( data );
//   });
// });
