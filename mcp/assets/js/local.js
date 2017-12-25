function wrappedPrettyMs(data, type, row) {
  if (data > 0) {
    return prettyMs(data, {compact: true})
  }

  return "-";
}

function humanizeState(data, type, row) {
  if (data) {
    return "active";
  } else {
    return "off";
  }
}

function prettyUs(data, type, row) {
  if (data > 0) {
    return prettyMs((data / 1000), {compact: true})
  }

  return "-";
}

function pageReady(jQuery) {
  jQuery.fn.dataTable.ext.errMode = 'throw';

  // Code to run when the document is ready.
  var switchTable = jQuery('#switchesTable').DataTable({
    dom: 'Bfrtip',
    ajax: "mcp/api/detail/switches",
    scrollY: '50vh',
    deferRender: true,
    scroller: true,
    select: true,
    order: [
      [ 1, "asc" ]
    ],
    columns: [ {
        data: "id",
        class: "col-center"
      },
      {data: "friendly_name"},
      {data: "device"},
      {data: "description"},
      {
        data: "dev_latency",
        class: "col-center",
        render: prettyUs
      },
      {
        data: "last_cmd_secs",
        class: "col-center",
        render: wrappedPrettyMs
      },
      {
        data: "last_seen_secs",
        class: "col-center",
        render: wrappedPrettyMs
      },
      {
        data: "state",
        class: "col-state-off",
        render: humanizeState
      }
    ],
    buttons: [ {
      text: 'Refresh',
      action: function (e, dt, node, config) {
        dt.button(0).processing(true);
        dt.ajax.reload();
        dt.button(0).processing(false);
        dt.button(0).text("Refreshed");
        dt.button(0).disable();
        setTimeout(function () {
          var dt = $('#switchesTable').DataTable();
          dt.button(0).text("Refresh");
          dt.button(0).enable();
        }, 10000);
      }
    } ]
  });

  var sensorTable = jQuery('#sensorsTable').DataTable({
    dom: 'Bfrtip',
    ajax: "mcp/api/detail/sensors",
    scrollY: '50vh',
    deferRender: true,
    scroller: true,
    select: true,
    order: [
      [ 1, "asc" ]
    ],
    columns: [ {
        data: "id",
        class: "col-center"
      }, {data: "friendly_name"},
      {data: "device"}, {data: "description"},
      {
        data: "dev_latency",
        class: "col-center",
        render: prettyUs
      },
      {
        data: "last_seen_secs",
        class: "col-center",
        render: prettyMs
      },
      {
        data: "reading_secs",
        class: "col-center",
        render: prettyMs
      },
      {
        data: "celsius",
        class: "col-center"
      }
    ],
    buttons: [ {
      text: 'Refresh',
      action: function (e, dt, node, config) {
        dt.button(0).processing(true);
        dt.ajax.reload();
        dt.button(0).processing(false);
        dt.button(0).text("Refreshed");
        dt.button(0).disable();
        setTimeout(function () {
          var dt = $('#sensorsTable').DataTable();
          dt.button(0).text("Refresh");
          dt.button(0).enable();
        }, 10000);
      }
    } ]
  });
}

function pageFullyLoaded() {
  setTimeout(function () {
    var masthead = jQuery('#mastheadText');
    masthead.removeClass('text-muted').addClass('text-ready');
  }, 10);
}

// var dt = require( 'datatables.net' )();
// $().DataTable();

jQuery(document).ready(pageReady);

jQuery(window).on("load", pageFullyLoaded);

jQuery("#collapseSwitches")
  .on('show.bs.collapse',
    function (event) {
      $('#switchesTable').DataTable().ajax.reload();
    });

jQuery("#collapseSensors")
  .on('show.bs.collapse',
    function (event) {
      $('#sensorsTable').DataTable().ajax.reload();
    });

// DEPRECATED -- left as a future example
//   jQuery.get( "mcp/detail/nodevice", function( data ) {
//     $( "#noDeviceCard" ).html( data );
//   });
// });
