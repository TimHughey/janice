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

function displayStatus(text) {
  const navBarAlert = jQuery('#navbarAlert');
  navBarAlert.text(text);
  navBarAlert.fadeToggle();
  navBarAlert.fadeOut(3000);
}

/* eslint-disable no-console */
function dataTableErrorHandler(settings, techNote, message) {
  displayStatus(message);
  console.log(settings, techNote, message);
}

function autoRefresh() {
  clearInterval(sessionStorage.getItem('autoRefreshInterval'));

  const ri = setInterval(
    () => {
      const tabs = ['switches', 'sensors'];
      tabs.forEach((elem) => {
        const table = jQuery('#$(elem)Table');
        const button = table.buttons(0);

        if (jQuery('#$(elem)Tab').hasClass('active') && (button.active())) {
          button.processing(true);
          table.ajax.reload(() => {
            button(0).processing(false);
          }, false);
        }
      });
    },
    3000,
  );

  sessionStorage(sessionStorage.setItem('autoRefreshInterval'), ri);
}

function switchColumns() {
  return [{
    data: 'id',
    class: 'col-center',
  },
  {
    data: 'name',
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
  ];
}

function sensorColumns() {
  return [{
    data: 'id',
    class: 'col-center',
  }, {
    data: 'name',
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
  ];
}

function createSwitchesTable() {
  const switchTable = jQuery('#switchesTable').DataTable({
    dom: 'Bfrtip',
    ajax: 'mcp/api/detail/switches',
    scrollY: '50vh',
    // deferRender: true,
    scroller: true,
    select: {
      style: 'single',
      items: 'row',
    },
    order: [
      [1, 'asc'],
    ],
    columns: switchColumns(),
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
        // console.log(
        //   'Switch Button Action', e, dt.ajax, node,
        //   config,
        // );

        if (switchTable.button(0).active()) {
          switchTable.button(0).active(false);
        } else {
          switchTable.button(0).active(true);
          autoRefresh();
        }
      },
    },
    {
      text: 'Rename',
      extend: 'selected',
      attr: {
        id: 'switchRenameButton',
      },
      action(e, dt, node, config) {
        const {
          name,
          id,
        } = switchTable.rows({
          selected: true,
        }).data()[0];

        const newName = jQuery('#generalInputBox').val();

        switchTable.button(1).processing(true);
        jQuery.ajax({
          url: `mcp/api/switch/${id}`,
          type: 'PATCH',
          data: {
            name: newName,
          },
          beforeSend(xhr) {
            // send the CSRF token included as a meta on the HTML page
            const token = jQuery("meta[name='csrf-token']").attr('content');
            xhr.setRequestHeader('X-CSRF-Token', token);
          },
          error(xhr, status, error) {
            console.log('error xhr:', xhr);
            displayStatus(`Error changing name of ${name}`);
          },
          success(xhr, status) {
            const response = xhr.responseJSON();
            displayStatus(`Switch name changed to ${response.name}`);
          },
          complete(xhr, status) {
            switchTable.ajax.reload(null, false);
            switchTable.button(1).processing(false);
            jQuery('#generalPurposeForm').fadeToggle();
          },
        });
      },
    },
    {
      text: 'Delete',
      extend: 'selected',
      attr: {
        id: 'switchDeleteButton',
      },
      action(e, dt, node, config) {
        const {
          device,
        } = switchTable.rows({
          selected: true,
        }).data()[0];

        switchTable.button(2).processing(true);
        jQuery.ajax({
          url: `mcp/api/switch/${encodeURIComponent(device)}`,
          type: 'DELETE',
          beforeSend(xhr) {
            // send the CSRF token included as a meta on the HTML page
            const token = jQuery("meta[name='csrf-token']").attr('content');
            xhr.setRequestHeader('X-CSRF-Token', token);
          },
          error(xhr, status, error) {
            console.log('error xhr:', xhr);
            displayStatus(`Error deleting ${device}`);
          },
          success(xhr, status) {
            displayStatus(`Deleted switch ${device}`);
          },
          complete(xhr, status) {
            switchTable.ajax.reload(null, false);
            switchTable.button(2).processing(false);
            jQuery('#generalPurposeForm').fadeToggle();
          },
        });
      },
    },
    {
      text: 'Toggle',
      extend: 'selected',
      attr: {
        id: 'switchToggleButton',
      },
      action(e, dt, node, config) {
        const {
          name,
          id,
        } = switchTable.rows({
          selected: true,
        }).data()[0];

        switchTable.button(3).processing(true);

        jQuery.ajax({
          url: `mcp/api/switch/${id}`,
          type: 'PATCH',
          data: {
            toggle: true,
          },
          beforeSend(xhr) {
            // send the CSRF token included as a meta on the HTML page
            const token = jQuery("meta[name='csrf-token']").attr('content');
            xhr.setRequestHeader('X-CSRF-Token', token);
          },
          error(xhr, status, error) {
            console.log('error xhr:', xhr);
            displayStatus(`Error toggling ${name}`);
          },
          success(xhr, status) {
            displayStatus(`Toggled switch ${name}`);
          },
          complete(xhr, status) {
            switchTable.ajax.reload(null, false);
            switchTable.button(3).processing(false);
            jQuery('#generalPurposeForm').fadeToggle();
          },
        });
      },
    }],
  });

  switchTable.button(0).active(true);

  switchTable.on('select', (e, dt, type, indexes) => {
    // console.log(e, dt, type, indexes);
    const lri = sessionStorage.getItem('switchRefreshInterval');
    clearInterval(lri);
    switchTable.button(0).active(false);

    const inputBox = jQuery('#generalPurposeForm');

    jQuery('#generalInputBox').attr(
      'placeholder',
      'Enter new switch name then click Rename',
    );
    inputBox.fadeIn('fast');
  });

  switchTable.on('deselect', (e, dt, type, indexes) => {
    // console.log(e, dt, type, indexes);
    const inputBox = jQuery('#generalPurposeForm');

    inputBox.fadeOut('fast');
  });
}

function createSensorsTable() {
  const sensorTable = jQuery('#sensorsTable').DataTable({
    dom: 'Bfrtip',
    ajax: 'mcp/api/detail/sensors',
    scrollY: '50vh',
    // deferRender: true,
    scroller: true,
    select: {
      style: 'single',
      items: 'row',
      // selector: 'td:nth-child(1)', // only allow devices to be selected
    },
    order: [
      [1, 'asc'],
    ],
    columns: sensorColumns(),
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
        // console.log('Sensor Button Action', e, dt, node, config);
        if (sensorTable.button(0).active()) {
          sensorTable.button(0).active(false);
        } else {
          sensorTable.button(0).active(true);
          autoRefresh();
        }
      },
    }, {
      text: 'Delete',
      extend: 'selected',
      attr: {
        id: 'sensorDeleteButton',
      },
      action(e, dt, node, config) {
        const {
          name,
          id,
        } = sensorTable.rows({
          selected: true,
        }).data()[0];

        sensorTable.button(0).processing(true);
        jQuery.ajax({
          url: `mcp/api/sensor/${id}`,
          type: 'DELETE',
          beforeSend(xhr) {
            // send the CSRF token included as a meta on the HTML page
            const token = jQuery("meta[name='csrf-token']").attr('content');
            xhr.setRequestHeader('X-CSRF-Token', token);
          },
          error(xhr, status, error) {
            console.log('error xhr:', xhr);
            displayStatus(`Error deleting ${name}`);
          },
          success(xhr, status) {
            displayStatus(`Deleted sensor ${name}`);
          },
          complete(xhr, status) {
            sensorTable.ajax.reload(null, false);
            sensorTable.button(0).processing(false);
          },
        });
      },
    },
    ],
  });

  sensorTable.button(0).active(true);
}

function pageReady(jQuery) {
  /* eslint-disable no-param-reassign */
  jQuery.fn.dataTable.ext.errMode = dataTableErrorHandler;
  /* eslint-enable no-param-reassign */

  createSwitchesTable();
  createSensorsTable();
  autoRefresh();

  jQuery('#mixtankProfile,dropdown-item').on('click', (event) => {
    const parent = event.target.parentNode;
    const mixtankName = parent.attributes.mixtankName.value;
    const newProfile = event.target.text;
    // console.log('via div ->', mixtankName, newProfile);
    // console.log(parent);

    jQuery.ajax({
      url: `mcp/api/mixtank/${mixtankName}`,
      type: 'PATCH',
      data: {
        newprofile: newProfile,
      },
      beforeSend(xhr) {
        // send the CSRF token included as a meta on the HTML page
        const token = jQuery("meta[name='csrf-token']").attr('content');
        xhr.setRequestHeader('X-CSRF-Token', token);
      },
      error(xhr, status, error) {
        console.log('error xhr:', xhr);
        displayStatus(`Error activating profile ${newProfile}`);
      },
    }).done((data) => {
      displayStatus(`Activated profile ${data.active_profile}`);
      // console.log(data);
    });

    jQuery('#dropdownMenuButton').text(newProfile);
  });

  jQuery('a[href="#switchesTab"]').on('shown.bs.tab', (event) => {
    $('#switchesTable').DataTable().ajax.reload(null, false);
  });

  jQuery('a[href="#sensorsTab"]').on('shown.bs.tab', (event) => {
    $('#sensorsTable').DataTable().ajax.reload(null, false);
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
