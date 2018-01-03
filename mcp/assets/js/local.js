// function isNumber(value) {
//   return typeof value === 'number' && Number.isFinite(value);
// }

function humanizeState(data, type, row) {
  if (data) {
    return 'active';
  }

  return 'off';
}

function prettySeconds(data, type, row) {
  if (data > 0) {
    return prettyMs((data * 1000), {
      compact: true,
    });
  }

  return 'now';
}

function prettyLastCommand(data, type, row) {
  if (data > 0) {
    return prettyMs((data * 1000), {
      compact: true,
    });
  }

  return '-';
}

function prettyUs(data, type, row) {
  if (data > 0) {
    return prettyMs((data / 1000), {
      compact: true,
    });
  }

  return '-';
}

function pageReady(jQuery) {
  jQuery.fn.dataTable.ext.errMode = 'throw';

  // Code to run when the document is ready.
  jQuery('#switchesTable').DataTable({
    dom: 'Bfrtip',
    ajax: 'mcp/api/detail/switches',
    scrollY: '50vh',
    // deferRender: true,
    scroller: true,
    select: {
      style: 'os',
      items: 'cell',
    },
    order: [
      [1, 'asc'],
    ],
    columns: [{
      data: 'id',
      class: 'col-center',
    },
    {
      data: 'friendly_name',
    }, {
      data: 'device',
    }, {
      data: 'description',
    },
    {
      data: 'dev_latency',
      class: 'col-center',
      render: prettyUs,
    }, {
      data: 'rt_latency',
      class: 'col-center',
      render: prettyUs,
    }, {
      data: 'last_cmd_secs',
      class: 'col-center',
      render: prettyLastCommand,
    }, {
      data: 'last_seen_secs',
      class: 'col-center',
      render: prettySeconds,
    }, {
      data: 'state',
      class: 'col-state-off',
      render: humanizeState,
    },
    ],
    columnDefs: [
      {
        targets: [0],
        visible: false,
        searchable: false,
      },
    ],
    buttons: [{
      text: 'Refresh',
      action(e, dt, node, config) {
        dt.button(0).processing(true);
        dt.ajax.reload();
        dt.button(0).processing(false);
        dt.button(0).text('Refreshed');
        dt.button(0).disable();
        setTimeout(() => {
          const dt = $('#switchesTable').DataTable();
          dt.button(0).text('Refresh');
          dt.button(0).enable();
        }, 10000);
      },
    }],
  });

  jQuery('#sensorsTable').DataTable({
    dom: 'Bfrtip',
    ajax: 'mcp/api/detail/sensors',
    scrollY: '50vh',
    // deferRender: true,
    scroller: true,
    select: true,
    order: [
      [1, 'asc'],
    ],
    columns: [{
      data: 'id',
      class: 'col-center',
    }, {
      data: 'friendly_name',
    }, {
      data: 'device',
    }, {
      data: 'description',
    },
    {
      data: 'dev_latency',
      class: 'col-center',
      render: prettyUs,
    }, {
      data: 'last_seen_secs',
      class: 'col-center',
      render: prettySeconds,
    }, {
      data: 'reading_secs',
      class: 'col-center',
      render: prettySeconds,
    }, {
      data: 'celsius',
      class: 'col-center',
    },
    ],
    columnDefs: [
      {
        targets: [0],
        visible: false,
        searchable: false,
      },
    ],
    buttons: [{
      text: 'Refresh',
      attr: {
        id: 'sensorRefreshButton',
      },
      action(e, dt, node, config) {
        dt.button(0).processing(true);
        dt.ajax.reload();
        dt.button(0).processing(false);
        dt.button(0).text('Refreshed');
        dt.button(0).disable();
        setTimeout(() => {
          const dt = $('#sensorsTable').DataTable();
          dt.button(0).text('Refresh');
          dt.button(0).enable();
        }, 10000);
      },
    }],
  });
}

function pageFullyLoaded() {
  setTimeout(() => {
    const masthead = jQuery('#mastheadText');
    masthead.removeClass('text-muted').addClass('text-ready');
  }, 10);
}

// var dt = require( 'datatables.net' )();
// $().DataTable();

jQuery(document).ready(pageReady);

jQuery(window).on('load', pageFullyLoaded);

jQuery('a[href="#switchesTab"]').on('shown.bs.tab', (event) => {
  $('#switchesTable').DataTable().ajax.reload();
});

jQuery('a[href="#sensorsTab"]').on('shown.bs.tab', (event) => {
  $('#sensorsTable').DataTable().ajax.reload();
});

// $('a[data-toggle="tab"]').on('show.bs.tab', (e) => {
//   console.log('data toggle');
//   console.log($(this).attr('id'));
//
//   if ($(this).attr('id') === 'nav-switches-tab') {
//     $('#switchesTable').DataTable().ajax.reload();
//   }
//
//   if ($(this).attr('id') === 'nav-sensors-tab') {
//     $('#sensorsTable').DataTable().ajax.reload();
//   }
//
//   // jQuery(e.target.href).DataTable().ajax.reload();
//   // console.log(e.target); // newly activated tab
//   // console.log(e.relatedTarget); // previous active tab
// });

// DEPRECATED -- left as a future example
//   jQuery.get( "mcp/detail/nodevice", function( data ) {
//     $( "#noDeviceCard" ).html( data );
//   });
// });
