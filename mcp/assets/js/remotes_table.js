import {
  prettySeconds,
  displayStatus,
  autoRefresh,
}
  from './merc_util';

function columns() {
  return [{
    data: 'id',
    class: 'col-center',
  }, {
    data: 'name',
  }, {
    data: 'host',
  }, {
    data: 'hw',
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

const refreshButton = {
  id() {
    return 'remoteRefreshButton';
  },
  num() {
    return 0;
  },
};

function create() {
  const remoteTable = jQuery('#remotesTable').DataTable({
    dom: 'Bfrtip',
    ajax: 'mcp/api/remote',
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
    columns: columns(),
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
        id: refreshButton.id(),
      },
      action(e, dt, node, config) {
        if (remoteTable.button(refreshButton.num()).active()) {
          remoteTable.button(refreshButton.num()).active(false);
        } else {
          remoteTable.button(refreshButton.num()).active(true);
          autoRefresh();
        }
      },
    },
    {
      text: 'Rename',
      extend: 'selected',
      attr: {
        id: 'remoteRenameButton',
      },
      action(e, dt, node, config) {
        const {
          name,
          id,
        } = remoteTable.rows({
          selected: true,
        }).data()[0];

        const newName = jQuery('#generalInputBox').val();

        remoteTable.button(1).processing(true);
        jQuery.ajax({
          url: `mcp/api/remote/${id}`,
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
            displayStatus(`Remote name changed to ${data.name}`);
            // const response = jqXHR.responseJSON();
            // displayStatus(`Sensor name changed to ${response}`);
          },
          complete(xhr, status) {
            remoteTable.ajax.reload(null, false);
            remoteTable.button(1).processing(false);
            jQuery('#generalPurposeForm').fadeToggle();
            remoteTable.button(0).active(true);
          },
        });
      },
    }, {
      text: 'Delete',
      extend: 'selected',
      attr: {
        id: 'remoteDeleteButton',
      },
      action(e, dt, node, config) {
        const {
          name,
          id,
        } = remoteTable.rows({
          selected: true,
        }).data()[0];

        remoteTable.button(2).processing(true);
        jQuery.ajax({
          url: `mcp/api/remote/${id}`,
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
            displayStatus(`Deleted remote ${name}`);
          },
          complete(xhr, status) {
            remoteTable.ajax.reload(null, false);
            remoteTable.button(2).processing(false);
            jQuery('#generalPurposeForm').fadeToggle();
            remoteTable.button(0).active(true);
          },
        });
      },
    },
    {
      text: 'OTA Update',
      extend: 'selected',
      attr: {
        id: 'remoteOtaUpdateButton',
      },
      action(e, dt, node, config) {
        const {
          name,
          id,
        } = remoteTable.rows({
          selected: true,
        }).data()[0];

        remoteTable.button(1).processing(true);
        jQuery.ajax({
          url: `mcp/api/remote/${id}`,
          type: 'PATCH',
          data: {
            ota_update: true,
          },
          dateType: 'json',
          beforeSend(xhr) {
            // send the CSRF token included as a meta on the HTML page
            const token = jQuery("meta[name='csrf-token']").attr('content');
            xhr.setRequestHeader('X-CSRF-Token', token);
          },
          error(xhr, status, error) {
            console.log('error xhr:', xhr);
            displayStatus(`Error triggering ota update for ${name}`);
          },
          success(data, status, jqXHR) {
            console.log(data, status, jqXHR);
            displayStatus(`OTA update triggered for ${data.name}`);
            // const response = jqXHR.responseJSON();
            // displayStatus(`Sensor name changed to ${response}`);
          },
          complete(xhr, status) {
            remoteTable.ajax.reload(null, false);
            remoteTable.button(1).processing(false);
            jQuery('#generalPurposeForm').fadeToggle();
            remoteTable.button(0).active(true);
          },
        });
      },
    },
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

export default {
  create,
};
