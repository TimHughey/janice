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

/* eslint-disable no-console */
function dataTableErrorHandler(settings, techNote, message) {
  console.log(settings, techNote, message);
}

function createSwitchesTable() {
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
          $('#switchesTable').DataTable();
          dt.button(0).text('Refresh');
          dt.button(0).enable();
        }, 1000);
      },
    }],
  });
}

function createSensorsTable() {
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
          $('#sensorsTable').DataTable();
          dt.button(0).text('Refresh');
          dt.button(0).enable();
        }, 1000);
      },
    }],
  });
}

function pageReady(jQuery) {
  /* eslint-disable no-param-reassign */
  jQuery.fn.dataTable.ext.errMode = dataTableErrorHandler;
  /* eslint-enable no-param-reassign */

  createSwitchesTable();
  createSensorsTable();

  jQuery('#mixtankProfile,dropdown-item').on('click', (event) => {
    const parent = event.target.parentNode;
    const mixtankName = parent.attributes.mixtankName.value;
    const newProfile = event.target.text;
    console.log('via div ->', mixtankName, newProfile);
    console.log(parent);

    jQuery.getJSON('mcp/api/mixtank', {
      action: 'change_profile',
      mixtank: mixtankName,
      profile: newProfile,
    }).done((data) => {
      console.log(data);
    });

    jQuery('#dropdownMenuButton').text(newProfile);
  });

  jQuery('a[href="#switchesTab"]').on('shown.bs.tab', (event) => {
    $('#switchesTable').DataTable().ajax.reload();
  });

  jQuery('a[href="#sensorsTab"]').on('shown.bs.tab', (event) => {
    $('#sensorsTable').DataTable().ajax.reload();
  });
}

function pageFullyLoaded() {
  setTimeout(() => {
    const masthead = jQuery('#mastheadText');
    masthead.removeClass('text-muted').addClass('text-ready');
  }, 10);
}

jQuery(document).ready(pageReady);

jQuery(window).on('load', pageFullyLoaded);
