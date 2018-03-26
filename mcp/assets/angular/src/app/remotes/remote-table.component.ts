import { Component, OnDestroy, OnInit } from '@angular/core';
import { Input, Output } from '@angular/core';

import { Subscription } from 'rxjs/Subscription';
import { Observable } from 'rxjs/Observable';
import { IntervalObservable } from 'rxjs/observable/IntervalObservable';
import 'rxjs/add/observable/interval';

import { RemoteApiResponse } from './remote-api-response';
import { RemoteService } from './remote.service';
import { Remote } from './remote';

@Component({
  selector: 'app-remote-table',
  templateUrl: './remote-table.component.html',
  styleUrls: ['./remote-table.component.css']
})
export class RemoteTableComponent implements OnInit, OnDestroy {

  ob = Observable.interval(3000);
  data$: Observable<Remote[]>;
  refresh: Subscription;

  response: RemoteApiResponse;
  remotes: Remote[];
  save: string;
  @Output() pending = new Array<Remote>();
  autoRefresh = true;

  constructor(private remoteService: RemoteService) { }

  loadData() {
    this.data$ = this.remoteService.getRemotes();

    // one-time
    this.data$.subscribe(r => this.setData(r));

    // repeating
    this.refresh = this.ob.
      subscribe(() => this.handleRefresh());
  }

  setData(remotes) { this.remotes = [...remotes]; }

  handleRefresh() {
    if (this.autoRefresh) { this.data$.subscribe(r => this.setData(r)); }
  }

  ngOnDestroy() {
    console.log('destroy');
    this.refresh.unsubscribe();
  }

  ngOnInit() {
    // this.interval = setInterval(() => this.loadData(), 3000);
    this.loadData();
  }

  blur({ event: event, local: local }) {
    console.log('blur:', event, this.save, local);
  }

  onEditCancel(event) {
    const changed: Remote = event.data;

    const index = this.remotes.findIndex((item: Remote) => item.id === changed.id);

    event.data.name = this.save;
    // this.remotes[index] = this.save[index];

    console.log('cancel:', event, index);
  }

  onEditComplete(event) {
    this.pending.push(event.data);
    console.log('complete:', event);
  }

  onEditInit(event) {
    this.save = event.data.name;
    this.autoRefresh = false;
    console.log('init: ', event, this.save);

  }
}
