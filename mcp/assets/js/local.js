import {
  boolToYesNo,
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
const dutycyclesID = '#dutycyclesTable';
const mixtanksID = '#mixtanksTable';
const gScrollY = '50vh';

function deleteButton(dt) {
  return dt.buttons('__delete:name');
}

function refreshButton(dt) {
  return dt.buttons('__refresh:name');
}

function otaAllButton(dt) {
  return dt.buttons('__otaAll:name');
}

function otaButtonGroup(dt) {
  return dt.buttons('__otaGroup:name');
}

// function otaSingleButton(dt) {
//   return dt.buttons('__otaSingle:name');
// }

function renameButton(dt) {
  return dt.buttons('__rename:name');
}

function restartButton(dt) {
  return dt.buttons('__restart:name');
}

function newDeleteButton(tableName) {
  return {
    text: 'Delete',
    extend: 'selected',
    name: '__delete',
    attr: {
      id: 'deleteButton',
    },
    action(e, dt, node, config) {
      const refresh = refreshButton(dt);
      const button = deleteButton(dt);
      const url = dt.ajax.url();

      const {
        name,
        id,
      } = dt.rows({
        selected: true,
      }).data()[0];

      button.processing(true);
      jQuery.ajax({
        url: `${url}/${id}`,
        type: 'DELETE',
        beforeSend(xhr) {
          // send the CSRF token included as a meta on the HTML page
          const token = jQuery("meta[name='csrf-token']").attr('content');
          xhr.setRequestHeader('X-CSRF-Token', token);
        },
        error(xhr, status, error) {
          displayStatus(`Error deleting ${name}`);
        },
        success(xhr, status) {
          displayStatus(`Deleted ${name}`);
        },
        complete(xhr, status) {
          dt.ajax.reload(null, false);
          button.processing(false);
          jQuery('#generalPurposeForm').fadeToggle();
          refresh.active(true);
        },
      });
    },
  };
}

function newMixtankProfileButton(tableName, profileName) {
  return {
    text: profileName,
    name: `__${profileName}`,
    attr: {
      id: `${tableName}${profileName}ButtonID`,
    },
    action(e, dt, node, config) {
      const refresh = refreshButton(dt);
      const groupButton = dt.buttons('__ProfileGroup:name');
      const profileButton = dt.buttons(`__${profileName}:name`);
      const url = dt.ajax.url();

      const {
        name,
        id,
      } = dt.rows({
        selected: true,
      }).data()[0];

      groupButton.processing(true);
      const newProfile = profileButton.text()[0];

      jQuery.ajax({
        url: `${url}/${id}`,
        type: 'PATCH',
        data: {
          name,
          newProfile,
        },
        beforeSend(xhr) {
          // send the CSRF token included as a meta on the HTML page
          const token = jQuery("meta[name='csrf-token']").attr('content');
          xhr.setRequestHeader('X-CSRF-Token', token);
        },
        error(jqXHR, status, error) {
          displayStatus(`Error changing profile to ${newProfile}`);
        },
        success(data, status, jqXHR) {
          if (data.restart === 'ok') {
            displayStatus(`Error changing profile to ${newProfile}`);
          } else {
            displayStatus(`Profile changed to ${newProfile}`);
          }
        },
        complete(xhr, status) {
          groupButton.processing(false);
          dt.rows().deselect();
          dt.ajax.reload(null, false);
          refresh.active(true);
        },
      });
    },
  };
}

function newMixtankProfilesButton(tableName, profiles) {
  const b = [];
  const len = profiles.length;

  for (let i = 0; i < len; i += 1) {
    b.push(newMixtankProfileButton(tableName, profiles[i]));
  }

  const a = {
    extend: 'collection',
    text: 'Profile',
    name: '__ProfileGroup',
    buttons: b,
    fade: true,
    autoClose: true,
  };

  return a;
}

function newOtaAllButton(tableName) {
  return {
    text: 'All',
    name: '__otaAll',
    attr: {
      id: `${tableName}OtaAllButtonID`,
    },
    action(e, dt, node, config) {
      const refresh = refreshButton(dt);
      const button = otaButtonGroup(dt);
      const url = dt.ajax.url();

      button.processing(true);
      jQuery('#generalPurposeForm').fade('fast');

      jQuery.ajax({
        url,
        data: {
          ota_all: true,
        },
        beforeSend(xhr) {
          // send the CSRF token included as a meta on the HTML page
          const token = jQuery("meta[name='csrf-token']").attr('content');
          xhr.setRequestHeader('X-CSRF-Token', token);
        },
        error(jqXHR, status, error) {
          displayStatus('Error triggering ota for all');
        },
        success(data, status, jqXHR) {
          if (data.ota_all_res === 'ok') {
            displayStatus('Triggered ota for all');
          } else {
            displayStatus('Failed triggering ota for all');
          }
        },
        complete(xhr, status) {
          dt.ajax.reload(null, false);
          button.processing(false);
          refresh.active(true);
        },
      });
    },
  };
}

function newOtaSingleButton(tableName) {
  return {
    text: 'Single',
    name: '__otaSingle',
    extend: 'selected',
    attr: {
      id: `${tableName}OtaSingleButtonID`,
    },
    action(e, dt, node, config) {
      const refresh = refreshButton(dt);
      const button = otaButtonGroup(dt);
      const url = dt.ajax.url();

      const {
        name,
        id,
      } = dt.rows({
        selected: true,
      }).data()[0];

      button.processing(true);
      jQuery('#generalPurposeForm').fadeToggle();

      jQuery.ajax({
        url: `${url}/${id}`,
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
          displayStatus(`Error triggering ota for ${name}`);
        },
        success(data, status, jqXHR) {
          displayStatus(`Triggered ota for ${name}`);
        },
        complete(xhr, status) {
          dt.ajax.reload(null, false);
          button.processing(false);

          refresh.active(true);
        },
      });
    },
  };
}

function newRefreshButton(tableName) {
  // const buttonName = `${tableName}RefreshButton`;
  const buttonName = '__refresh';
  return {
    text: 'Refresh',
    name: buttonName,
    attr: {
      id: `${tableName}RefreshButtonID`,
    },
    action(e, dt, node, config) {
      const button = refreshButton(dt);

      if (button.active()) {
        button.active(false);
      } else {
        button.active(true);
        autoRefresh();
      }
    },
  };
}

function newRenameButton(tableName) {
  return {
    text: 'Rename',
    name: '__rename',
    extend: 'selected',
    attr: {
      id: `${tableName}RenameButtonID`,
    },
    action(e, dt, node, config) {
      const refresh = refreshButton(dt);
      const rename = renameButton(dt);
      const url = dt.ajax.url();

      const {
        name,
        id,
      } = dt.rows({
        selected: true,
      }).data()[0];

      const newName = jQuery('#generalInputBox').val();

      rename.processing(true);
      jQuery.ajax({
        url: `${url}/${id}`,
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
          displayStatus(`Error changing name of ${name}`);
        },
        success(data, status, jqXHR) {
          displayStatus(`Name changed to ${data.name}`);
          // const response = jqXHR.responseJSON();
          // displayStatus(`Sensor name changed to ${response}`);
        },
        complete(xhr, status) {
          dt.ajax.reload(null, false);
          rename.processing(false);
          jQuery('#generalPurposeForm').fadeToggle();
          refresh.active(true);
        },
      });
    },
  };
}

function newRestartButton(tableName) {
  return {
    text: 'Restart',
    name: '__restart',
    extend: 'selected',
    attr: {
      id: `${tableName}RestartButtonID`,
    },
    action(e, dt, node, config) {
      const refresh = refreshButton(dt);
      const restart = restartButton(dt);
      const url = dt.ajax.url();

      const {
        name,
        id,
      } = dt.rows({
        selected: true,
      }).data()[0];

      restart.processing(true);

      jQuery.ajax({
        url: `${url}/${id}`,
        type: 'PATCH',
        data: {
          restart: true,
        },
        beforeSend(xhr) {
          // send the CSRF token included as a meta on the HTML page
          const token = jQuery("meta[name='csrf-token']").attr('content');
          xhr.setRequestHeader('X-CSRF-Token', token);
        },
        error(jqXHR, status, error) {
          displayStatus(`Error triggering restart for ${name}`);
        },
        success(data, status, jqXHR) {
          if (data.restart === 'ok') {
            displayStatus(`Restart triggered for ${name}`);
          } else {
            displayStatus(`Restart trigger failed for ${name}`);
          }
        },
        complete(xhr, status) {
          dt.ajax.reload(null, false);
          restart.processing(false);
          jQuery('#generalPurposeForm').fadeToggle();
          refresh.active(true);
        },
      });
    },
  };
}

function toggleButton(tableName) {
  return {
    text: 'Toggle',
    name: '__toggle',
    extend: 'selected',
    attr: {
      id: 'toggleButton',
    },
    action(e, dt, node, config) {
      const refresh = refreshButton(dt);
      const toggle = toggleButton(dt);
      const url = dt.ajax.url();

      const {
        name,
        id,
      } = dt.rows({
        selected: true,
      }).data()[0];

      toggle.processing(true);

      jQuery.ajax({
        url: `${url}/${id}`,
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
          displayStatus(`Error toggling ${name}`);
        },
        success(data, status, jqXHR) {
          displayStatus(`Toggled switch ${name}`);
        },
        complete(xhr, status) {
          dt.ajax.reload(null, false);
          toggle.processing(false);
          jQuery('#generalPurposeForm').fadeToggle();
          refresh.active(true);
        },
      });
    },
  };
}

function sensorsColumns() {
  return [{
    data: 'id',
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
  const tableName = 'Sensors';
  const table = jQuery(sensorsID).DataTable({
    dom: 'Bfrtip',
    ajax: {
      url: 'mcp/api/sensor',
      complete(jqXHR, textStatus) {
        const {
          status,
          statusText,
        } = jqXHR;
        if (status !== 200) {
          displayStatus(`Refresh Error: ${statusText}`);
        }
      },
    },
    scrollY: gScrollY,
    scrollCollapse: true,
    paging: false,
    attr: [{
      api_frag: 'sensor',
    }],
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
    buttons: [newRefreshButton(tableName),
      newRenameButton(tableName),
      newDeleteButton(tableName)],
  });

  refreshButton(table).active(true);

  table.on('select', (e, dt, type, indexes) => {
    refreshButton(dt).active(false);

    const inputForm = jQuery('#generalPurposeForm');

    jQuery('#generalInputTextLabel').text('New Sensor Name');

    jQuery('#generalInputBox').attr(
      'placeholder',
      'Enter new sensor name here then press Rename',
    );

    jQuery('#generalInputBox').focus();
    inputForm.fadeIn('fast');
  });

  table.on('deselect', (e, dt, type, indexes) => {
    const inputBox = jQuery('#generalPurposeForm');
    refreshButton(dt).active(true);

    inputBox.fadeOut('fast');
  });
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
  const tableName = 'Switches';
  const table = jQuery(switchesID).DataTable({
    dom: 'Bfrtip',
    ajax: {
      url: 'mcp/api/switch',
      complete(jqXHR, textStatus) {
        const {
          status,
          statusText,
        } = jqXHR;
        if (status !== 200) {
          displayStatus(`Refresh Error: ${statusText}`);
        }
      },
    },
    scrollY: gScrollY,
    scrollCollapse: true,
    paging: false,
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
    buttons: [newRefreshButton(tableName),
      newRenameButton(tableName),
      newDeleteButton(tableName),
      toggleButton(tableName),
    ],
  });

  refreshButton(table).active(true);

  table.on('select', (e, dt, type, indexes) => {
    refreshButton(dt).active(false);

    const inputForm = jQuery('#generalPurposeForm');

    jQuery('#generalInputTextLabel').text('RENAME');

    jQuery('#generalInputBox').attr(
      'placeholder',
      'Enter new switch name here then click Rename',
    );

    jQuery('#generalInputBox').focus();
    inputForm.fadeIn('fast');
  });

  table.on('deselect', (e, dt, type, indexes) => {
    const inputBox = jQuery('#generalPurposeForm');
    refreshButton(dt).active(true);

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
  const tableName = 'Remotes';
  const table = jQuery(remotesID).DataTable({
    dom: 'Bfrtip',
    ajax: {
      url: 'mcp/api/remote',
      complete(jqXHR, textStatus) {
        const {
          status,
          statusText,
        } = jqXHR;
        if (status !== 200) {
          displayStatus(`Refresh Error: ${statusText}`);
        }
      },
    },
    scrollY: gScrollY,
    scrollCollapse: true,
    paging: false,
    searching: false,
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
    buttons: [newRefreshButton(tableName),
      newRenameButton(tableName),
      newDeleteButton(tableName),
      {
        extend: 'collection',
        text: 'OTA',
        name: '__otaGroup',
        buttons: [
          newOtaSingleButton(tableName),
          newOtaAllButton(tableName),
        ],
        fade: true,
        autoClose: true,
      },

      newRestartButton(tableName)],
  });

  refreshButton(table).active(true);

  table.on('select', (e, dt, type, indexes) => {
    refreshButton(dt).active(false);
    otaAllButton(dt).disable();
    restartButton(dt).enable();

    const inputForm = jQuery('#generalPurposeForm');

    jQuery('#generalInputTextLabel').text('RENAME');

    jQuery('#generalInputBox').attr(
      'placeholder',
      'Enter new remote name here then click Rename',
    );

    jQuery('#generalInputBox').focus();
    inputForm.fadeIn('fast');
  });

  table.on('deselect', (e, dt, type, indexes) => {
    const inputBox = jQuery('#generalPurposeForm');
    refreshButton(dt).active(true);
    otaAllButton(dt).enable();
    restartButton(dt).disable();

    inputBox.fadeOut('fast');
  });
}

function dutycyclesColumns() {
  return [{
    data: 'id',
    class: 'col-center',
  }, {
    data: 'name',
  }, {
    data: 'comment',
  }, {
    data: 'enable',
    class: 'col-center',
    render: boolToYesNo,
  },
  {
    data: 'standalone',
    class: 'col-center',
    render: boolToYesNo,
  }, {
    data: 'device',
    class: 'col-center',
  }, {
    data: 'state.state_at_secs',
    class: 'col-center',
    render: prettySeconds,
  }, {
    data: 'state.run_at_secs',
    class: 'col-center',
    render: prettySeconds,
  }, {
    data: 'state.idle_at_secs',
    class: 'col-center',
    render: prettySeconds,
  },
  ];
}

function createDutycyclesTable() {
  const tableName = 'Dutycycles';
  const table = jQuery(dutycyclesID).DataTable({
    dom: 'Bfrtip',
    ajax: {
      url: 'mcp/api/dutycycle',
      complete(jqXHR, textStatus) {
        const {
          status,
          statusText,
        } = jqXHR;
        if (status !== 200) {
          displayStatus(`Refresh Error: ${statusText}`);
        }
      },
    },
    class: 'compact',
    scrollY: gScrollY,
    scrollCollapse: true,
    paging: false,
    select: {
      style: 'single',
      items: 'row',
      // selector: 'td:nth-child(1)', // only allow devices to be selected
    },
    order: [
      [1, 'asc'],
    ],
    columns: dutycyclesColumns(),
    columnDefs: [
      {
        targets: [0, 2],
        visible: false,
        searchable: false,
      },
    ],
    buttons: [newRefreshButton(tableName),
    ],
  });

  refreshButton(table).active(true);

  table.on('select', (e, dt, type, indexes) => {
    refreshButton(dt).active(false);

    const inputForm = jQuery('#generalPurposeForm');

    jQuery('#generalInputTextLabel').text('RENAME');

    jQuery('#generalInputBox').attr(
      'placeholder',
      'Enter new dutycycle name here then click Rename',
    );

    jQuery('#generalInputBox').focus();
    inputForm.fadeIn('fast');
  });

  table.on('deselect', (e, dt, type, indexes) => {
    const inputBox = jQuery('#generalPurposeForm');
    refreshButton(dt).active(true);

    inputBox.fadeOut('fast');
  });
}

function mixtanksColumns() {
  return [{
    data: 'id',
    class: 'col-center',
  }, {
    data: 'name',
  }, {
    data: 'comment',
  }, {
    data: 'enable',
    class: 'col-center',
    render: boolToYesNo,
  },
  {
    data: 'state.state',
    class: 'col-center',
  },
  {
    data: 'sensor',
    class: 'col-center',
  }, {
    data: 'ref_sensor',
    class: 'col-center',
  }, {
    data: 'state.state_at_secs',
    class: 'col-center',
    render: prettySeconds,
  }, {
    data: 'state.started_at_secs',
    class: 'col-center',
    render: prettySeconds,
  },
  ];
}

function createMixtanksTable() {
  const tableName = 'Mixtanks';
  const table = jQuery(mixtanksID).DataTable({
    dom: 'Bfrtip',
    ajax: {
      url: 'mcp/api/mixtank',
      complete(jqXHR, textStatus) {
        const {
          status,
          statusText,
        } = jqXHR;
        if (status !== 200) {
          displayStatus(`Refresh Error: ${statusText}`);
        }
      },
    },
    class: 'compact',
    scrollY: gScrollY,
    scrollCollapse: true,
    paging: false,
    searching: false,
    select: {
      style: 'single',
      items: 'row',
      // selector: 'td:nth-child(1)', // only allow devices to be selected
    },
    order: [
      [1, 'asc'],
    ],
    columns: mixtanksColumns(),
    columnDefs: [
      {
        targets: [0, 2],
        visible: false,
        searchable: false,
      },
    ],
    buttons: [newRefreshButton(tableName),
    ],
  });

  // table.button().add(newMixtankProfileButton(tableName, data.profile_names[
  //   0]));

  refreshButton(table).active(true);

  table.on('select', (e, dt, type, indexes) => {
    refreshButton(dt).active(false);

    // const inputForm = jQuery('#generalPurposeForm');
    //
    // jQuery('#generalInputTextLabel').text('RENAME');
    //
    // jQuery('#generalInputBox').attr(
    //   'placeholder',
    //   'Enter new mixtank name here then click Rename',
    // );
    //
    // jQuery('#generalInputBox').focus();
    // inputForm.fadeIn('fast');
    const data = table.data();
    const profileNames = data[0].profile_names;
    dt.button().add(1, newMixtankProfilesButton(
      tableName,
      profileNames,
    ));
  });

  table.on('deselect', (e, dt, type, indexes) => {
    const inputBox = jQuery('#generalPurposeForm');
    refreshButton(dt).active(true);

    inputBox.fadeOut('fast');

    dt.button(1).remove();
  });
}

function pageReady(jQuery) {
  /* eslint-disable no-param-reassign */
  jQuery.fn.dataTable.ext.errMode = dataTableErrorHandler;
  /* eslint-enable no-param-reassign */

  createSensorsTable();
  createSwitchesTable();
  createRemotesTable();
  createDutycyclesTable();
  createMixtanksTable();
  autoRefresh();

  // this must be the last thing -- after all tables created
  const tabs = ['switches', 'sensors', 'remotes', 'dutycycles',
    'mixtanks'];
  tabs.forEach((elem) => {
    const href = jQuery(`a[href="#${elem}Tab"]`);
    const table = jQuery(`#${elem}Table`).DataTable();

    href.on('hide.bs.tab', (event) => {
      const inputBox = jQuery('#generalPurposeForm');
      inputBox.fadeOut('fast');
    });

    href.on('shown.bs.tab', (event) => {
      table.ajax.reload(null, false);
    });
  });
}

function pageFullyLoaded() {
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
