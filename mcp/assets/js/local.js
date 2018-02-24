import {
  humanizeState,
  prettySeconds,
  prettyLastCommand,
  prettyUs,
  displayStatus,
  dataTableErrorHandler,
  autoRefresh,
}
  from './merc_util';

const sensorsID = '#sensorsTable';
const switchesID = '#switchesTable';
const remotesID = '#remotesTable';
const gScrollY = '50vh';

function refreshButton(tableID) {
  return {
    text: 'Refresh',
    attr: {
      id: 'refreshButton',
    },
    action(e, dt, node, config) {
      if (jQuery(tableID).DataTable.button(0).active()) {
        jQuery(tableID).DataTable.button(0).active(false);
      } else {
        jQuery(tableID).DataTable.button(0).active(true);
        autoRefresh();
      }
    },
  };
}

function renameButton(tableID, api) {
  return {
    text: 'Rename',
    extend: 'selected',
    attr: {
      id: 'renameButton',
    },
    action(e, dt, node, config) {
      const {
        name,
        id,
      } = jQuery(tableID).DataTable().rows({
        selected: true,
      }).data()[0];

      const newName = jQuery('#generalInputBox').val();

      jQuery(tableID).DataTable().button(1).processing(true);
      jQuery.ajax({
        url: `mcp/api/${api}/${id}`,
        type: 'PATCH',
        data: {
          name: newName,
        },
        dateType: 'json',
        beforeSend(xhr) {
          // send the CSRF token included as a meta on the HTML page
          const token = jQuery("meta[name='csrf-token']").attr('content');
          xhr.setRequestHeader('X-CSRF-Token', token);
        },
        error(xhr, status, error) {
          console.log('error xhr:', xhr);
          displayStatus(`Error changing name of ${name}`);
        },
        success(data, status, jqXHR) {
          console.log(data, status, jqXHR);
          displayStatus(`Sensor name changed to ${data.name}`);
          // const response = jqXHR.responseJSON();
          // displayStatus(`Sensor name changed to ${response}`);
        },
        complete(xhr, status) {
          jQuery(tableID).DataTable().ajax.reload(null, false);
          jQuery(tableID).DataTable().button(1).processing(false);
          jQuery('#generalPurposeForm').fadeToggle();
          jQuery(tableID).DataTable().button(0).active(true);
        },
      });
    },
  };
}

function deleteButton(tableID, api) {
  return {

    text: 'Delete',
    extend: 'selected',
    attr: {
      id: 'deleteButton',
    },
    action(e, dt, node, config) {
      const {
        name,
        id,
      } = jQuery(tableID).DataTable().rows({
        selected: true,
      }).data()[0];

      jQuery(tableID).DataTable().button(2).processing(true);
      jQuery.ajax({
        url: `mcp/api/${api}/${id}`,
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
          jQuery(tableID).DataTable().ajax.reload(null, false);
          jQuery(tableID).DataTable().button(2).processing(false);
          jQuery('#generalPurposeForm').fadeToggle();
          jQuery(tableID).DataTable().button(0).active(true);
        },
      });
    },
  };
}

function toggleButton(tableID, api) {
  return {
    text: 'Toggle',
    extend: 'selected',
    attr: {
      id: 'toggleButton',
    },
    action(e, dt, node, config) {
      const {
        name,
        id,
      } = jQuery(tableID).DataTable().rows({
        selected: true,
      }).data()[0];

      jQuery(tableID).DataTable().button(3).processing(true);

      jQuery.ajax({
        url: `mcp/api/${api}/${id}`,
        type: 'PATCH',
        data: {
          toggle: true,
        },
        beforeSend(xhr) {
          // send the CSRF token included as a meta on the HTML page
          const token = jQuery("meta[name='csrf-token']").attr('content');
          xhr.setRequestHeader('X-CSRF-Token', token);
        },
        error(jqXHR, status, error) {
          console.log('error xhr:', jqXHR);
          displayStatus(`Error toggling ${name}`);
        },
        success(data, status, jqXHR) {
          displayStatus(`Toggled switch ${name}`);
        },
        complete(xhr, status) {
          jQuery(tableID).DataTable().ajax.reload(null, false);
          jQuery(tableID).DataTable().button(3).processing(false);
          jQuery('#generalPurposeForm').fadeToggle();
          jQuery(tableID).DataTable().button(0).active(true);
        },
      });
    },
  };
}

function otaButton(tableID, api) {
  return {
    text: 'OTA (Single)',
    extend: 'selected',
    attr: {
      id: 'otaButton',
    },
    action(e, dt, node, config) {
      const {
        name,
        id,
      } = jQuery(tableID).DataTable().rows({
        selected: true,
      }).data()[0];

      jQuery(tableID).DataTable().button(3).processing(true);

      jQuery.ajax({
        url: `mcp/api/${api}/${id}`,
        type: 'PATCH',
        data: {
          ota: true,
        },
        beforeSend(xhr) {
          // send the CSRF token included as a meta on the HTML page
          const token = jQuery("meta[name='csrf-token']").attr('content');
          xhr.setRequestHeader('X-CSRF-Token', token);
        },
        error(jqXHR, status, error) {
          console.log('error xhr:', jqXHR);
          displayStatus(`Error triggering ota for ${name}`);
        },
        success(data, status, jqXHR) {
          displayStatus(`Triggered ota for ${name}`);
        },
        complete(xhr, status) {
          jQuery(tableID).DataTable().ajax.reload(null, false);
          jQuery(tableID).DataTable().button(3).processing(false);
          jQuery('#generalPurposeForm').fadeToggle();
          jQuery(tableID).DataTable().button(0).active(true);
        },
      });
    },
  };
}

function sensorsColumns() {
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

function createSensorsTable() {
  const sensorTable = jQuery(sensorsID).DataTable({
    dom: 'Bfrtip',
    ajax: 'mcp/api/sensor',
    scrollY: gScrollY,
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
    columns: sensorsColumns(),
    columnDefs: [
      {
        targets: [0],
        visible: false,
        searchable: false,
      },
    ],
    buttons: [refreshButton(sensorsID),
      renameButton(sensorsID, 'sensor'),
      deleteButton(sensorsID, 'sensor'),
    ],
  });

  sensorTable.on('select', (e, dt, type, indexes) => {
    sensorTable.button(0).active(false);

    const inputBox = jQuery('#generalPurposeForm');

    jQuery('#generalInputBox').attr(
      'placeholder',
      'Enter new sensor name here then press Rename',
    );
    inputBox.fadeIn('fast');
  });

  sensorTable.on('deselect', (e, dt, type, indexes) => {
    const inputBox = jQuery('#generalPurposeForm');
    sensorTable.button(0).active(true);

    inputBox.fadeOut('fast');
  });

  sensorTable.button(0).active(true);
}

function switchesColumns() {
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

function createSwitchesTable() {
  const switchTable = jQuery(switchesID).DataTable({
    dom: 'Bfrtip',
    ajax: 'mcp/api/switch',
    scrollY: gScrollY,
    // deferRender: true,
    scroller: true,
    select: {
      style: 'single',
      items: 'row',
    },
    order: [
      [1, 'asc'],
    ],
    columns: switchesColumns(),
    columnDefs: [
      {
        targets: [0],
        visible: false,
        searchable: false,
      },
    ],
    buttons: [refreshButton(switchesID),
      renameButton(switchesID, 'switch'),
      deleteButton(switchesID, 'switch'),
      toggleButton(switchesID, 'switch')],
  });

  switchTable.button(0).active(true);

  switchTable.on('select', (e, dt, type, indexes) => {
    switchTable.button(0).active(false);

    const inputBox = jQuery('#generalPurposeForm');

    jQuery('#generalInputBox').attr(
      'placeholder',
      'Enter new switch name then click Rename',
    );
    inputBox.fadeIn('fast');
  });

  switchTable.on('deselect', (e, dt, type, indexes) => {
    const inputBox = jQuery('#generalPurposeForm');
    switchTable.button(0).active(true);

    inputBox.fadeOut('fast');
  });
}

function remotesColumns() {
  return [{
    data: 'id',
    class: 'col-center',
  }, {
    data: 'name',
  }, {
    data: 'host',
  }, {
    data: 'hw',
    class: 'col-center',
  },
  {
    data: 'firmware_vsn',
    class: 'col-center',
  }, {
    data: 'preferred_vsn',
    class: 'col-center',
  }, {
    data: 'last_start_secs',
    class: 'col-center',
    render: prettySeconds,
  }, {
    data: 'last_seen_secs',
    class: 'col-center',
    render: prettySeconds,
  }, {
    data: 'at_preferred_vsn',
    class: 'col-center',
  },
  ];
}

function createRemotesTable() {
  const remoteTable = jQuery(remotesID).DataTable({
    dom: 'Bfrtip',
    ajax: 'mcp/api/remote',
    scrollY: 200,
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
    columns: remotesColumns(),
    columnDefs: [
      {
        targets: [0],
        visible: false,
        searchable: false,
      },
    ],
    buttons: [refreshButton(remotesID),
      renameButton(remotesID, 'remote'),
      deleteButton(remotesID, 'remote'),
      otaButton(remotesID, 'remote'),
    ],
  });

  remoteTable.on('select', (e, dt, type, indexes) => {
    remoteTable.button(0).active(false);

    const inputBox = jQuery('#generalPurposeForm');

    jQuery('#generalInputBox').attr(
      'placeholder',
      'Enter new remote name here then press Rename',
    );
    inputBox.fadeIn('fast');
  });

  remoteTable.on('deselect', (e, dt, type, indexes) => {
    const inputBox = jQuery('#generalPurposeForm');
    remoteTable.button(0).active(true);

    inputBox.fadeOut('fast');
  });

  remoteTable.button(0).active(true);
}

function pageReady(jQuery) {
  /* eslint-disable no-param-reassign */
  jQuery.fn.dataTable.ext.errMode = dataTableErrorHandler;
  /* eslint-enable no-param-reassign */

  createSensorsTable();
  createSwitchesTable();
  createRemotesTable();
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
}

function pageFullyLoaded() {
  const tabs = ['switches', 'sensors', 'remotes'];
  tabs.forEach((elem) => {
    const href = `a[href="#${elem}Tab"]`;
    const table = `#${elem}Table`;

    jQuery(href).on('shown.bs.tab', (event) => {
      jQuery(table).DataTable().ajax.reload(null, false);
    });
  });

  setTimeout(() => {
    const masthead = jQuery('#mastheadText');
    masthead.removeClass('text-muted').addClass('text-ready');
  }, 10);

  document.addEventListener(
    'visibilitychange', autoRefresh,
    false,
  );
}

jQuery(document).ready(pageReady);

jQuery(window).on('load', pageFullyLoaded);
