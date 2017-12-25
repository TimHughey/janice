function minutesToSecs(minutes) { return minutes * 60; }

function minutesInRange(val, low, high) {
  if (val >= minutesToSecs(low) && (val < minutesToSecs(high))) {
    return true;
  } else {
    return false;
  }
}

function humanizeMS(data, type, row) {
  if (data <= 2) {
    return "now";
  } else if (data < 60) {
    return `${data} secs`;
  } else if (minutesInRange(data, 1, 5)) {
    return ">1 min";
  } else if (minutesInRange(data, 5, 10)) {
    return ">5 min";
  } else if (minutesInRange(data, 10, 30)) {
    return ">10 min";
  } else if (minutesInRange(data, 30, 1440)) {
    return ">30 min";
  } else if (minutesInRange(data, 1440, 2880)) {
    return ">1 day";
  } else if (minutesInRange(data, 2880, 5760)) {
    return ">1 week";
  } else if (minutesInRange(data, 5760, 43200)) {
    return ">2 weeks";
  } else if (minutesInRange(data, 43200, 86400)) {
    return ">1 month";
  } else {
    return ">2 months";
  }
}

function humanizeState(data, type, row) {
  if (data) {
    return "active";
  } else {
    return "off";
  }
}

function humanizeUS(data, type, row) {
  if (data == null) {
    return "-";
  } else if (data < 1000) {
    return `${data} us`;
  } else {
    return `${Math.round((data / 1000), 2)} ms`;
  }
}

function pageReady(jQuery) {
  jQuery.fn.dataTable.ext.errMode = 'throw';

  // Code to run when the document is ready.
  var switchTable = $('#switchesTable').DataTable({
    dom : 'Bfrtip',
    ajax : "mcp/api/detail/switches",
    scrollY : '50vh',
    deferRender : true,
    scroller : true,
    select : true,
    order : [ [ 1, "asc" ] ],
    columns : [
      {data : "id", class : "col-center"}, {data : "friendly_name"},
      {data : "device"}, {data : "description"},
      {data : "dev_latency", class : "col-center", render : humanizeUS},
      {data : "last_cmd_secs", class : "col-center", render : humanizeMS},
      {data : "last_seen_secs", class : "col-center", render : humanizeMS},
      {data : "state", class : "col-state-off", render : humanizeState}
    ],
    buttons : [ {
      text : 'Refresh',
      action : function(e, dt, node, config) {
        dt.button(0).processing(true);
        dt.ajax.reload();
        dt.button(0).processing(false);
        dt.button(0).text("Refreshed");
        dt.button(0).disable();
        setTimeout(function() {
          var dt = $('#switchesTable').DataTable();
          dt.button(0).text("Refresh");
          dt.button(0).enable();
        }, 10000);
      }
    } ]
  });

  var sensorTable = $('#sensorsTable').DataTable({
    dom : 'Bfrtip',
    ajax : "mcp/api/detail/sensors",
    scrollY : '50vh',
    deferRender : true,
    scroller : true,
    select : true,
    order : [ [ 1, "asc" ] ],
    columns : [
      {data : "id", class : "col-center"}, {data : "friendly_name"},
      {data : "device"}, {data : "description"},
      {data : "dev_latency", class : "col-center", render : humanizeUS},
      {data : "last_seen_secs", class : "col-center", render : humanizeMS},
      {data : "reading_secs", class : "col-center", render : humanizeMS},
      {data : "celsius", class : "col-center"}
    ],
    buttons : [ {
      text : 'Refresh',
      action : function(e, dt, node, config) {
        dt.button(0).processing(true);
        dt.ajax.reload();
        dt.button(0).processing(false);
        dt.button(0).text("Refreshed");
        dt.button(0).disable();
        setTimeout(function() {
          var dt = $('#sensorsTable').DataTable();
          dt.button(0).text("Refresh");
          dt.button(0).enable();
        }, 10000);
      }
    } ]
  });
}

function pageFullyLoaded() {
  setTimeout(function() {
    var masthead = $('#mastheadText');
    masthead.removeClass('text-muted').addClass('text-ready');
  }, 10);
}

// var dt = require( 'datatables.net' )();
// $().DataTable();

jQuery(document).ready(pageReady);

jQuery(window).on("load", pageFullyLoaded);

jQuery("#collapseSwitches")
    .on('show.bs.collapse',
        function(event) { $('#switchesTable').DataTable().ajax.reload(); });

jQuery("#collapseSensors")
    .on('show.bs.collapse',
        function(event) { $('#sensorsTable').DataTable().ajax.reload(); });

// DEPRECATED -- left as a future example
//   jQuery.get( "mcp/detail/nodevice", function( data ) {
//     $( "#noDeviceCard" ).html( data );
//   });
// });
