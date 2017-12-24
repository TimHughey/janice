function minutes_to_secs(minutes) {
  return minutes * 60;
}

function minutes_in_range(val, low, high) {
  if (val >= minutes_to_secs(low) && (val < minutes_to_secs(high))) {
    return true;
  }
  else {
    return false;
  }
}

function humanize_ms(data, type, row) {
  if (data <= 2) { return "now"; }
  else if (data < 60) { return `${data} secs`; }
  else if (minutes_in_range(data, 1, 5)) { return ">1 min"; }
  else if (minutes_in_range(data, 5, 10)) { return ">5 min"; }
  else if (minutes_in_range(data, 10, 30)) { return ">10 min"; }
  else if (minutes_in_range(data, 30, 1440)) { return ">30 min"; }
  else if (minutes_in_range(data, 1440, 2880)) { return ">1 day"; }
  else if (minutes_in_range(data, 2880, 5760)) { return ">1 week"; }
  else if (minutes_in_range(data, 5760, 43200)) { return ">2 weeks"; }
  else if (minutes_in_range(data, 43200, 86400)) { return ">1 month"; }
  else { return ">2 months"; }

  return "error";
}

function humanize_state(data, type, row) {
  if (data) { return "active"; }
  else { return "off"; }
}

function humanize_us(data, type, row) {
  if (data == null) { return "-"; }
  else if (data < 1000) {return `${data} us`; }
  else { return `${Math.round((data / 1000), 2)} ms`; }
}

function pageReady( jQuery ) {
    $.fn.dataTable.ext.errMode = 'throw';

    // Code to run when the document is ready.
    var switchTable = $('#switchesTable').DataTable( {
      dom: 'Bfrtip',
      ajax: "mcp/api/detail/switches",
      scrollY: '50vh',
      deferRender: true,
      scroller: true,
      select: true,
      columns: [
        {data: "id", class: "col-center"},
        {data: "friendly_name"},
        {data: "device"},
        // {data: "enabled", class: "col-center"},
        {data: "description"},
        {data: "dev_latency", class: "col-center", render: humanize_us},
        {data: "last_cmd_secs", class: "col-center", render: humanize_ms},
        {data: "last_seen_secs", class: "col-center", render: humanize_ms},
        {data: "state", class: "col-state-off", render: humanize_state}
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
      ajax: "mcp/api/detail/sensors",
      scrollY: '50vh',
      deferRender: true,
      scroller: true,
      select: true,
      "columns": [
        {data: "id", class: "col-center"},
        {data: "friendly_name"},
        {data: "device"},
        {data: "description"},
        {data: "dev_latency", class: "col-center", render: humanize_us},
        {data: "last_seen_secs", class: "col-center", render: humanize_ms},
        {data: "reading_secs", class: "col-center", render: humanize_ms},
        {data: "celsius", class: "col-center"}
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
