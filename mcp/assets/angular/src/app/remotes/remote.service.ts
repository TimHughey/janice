import { Injectable } from '@angular/core';
import { Http, Response } from '@angular/http';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs/Observable';
import { of } from 'rxjs/observable/of';
import { catchError, map, tap } from 'rxjs/operators';

import { Remote } from './remote';
import { RemoteApiResponse } from './remote-api-response';

@Injectable()
export class RemoteService {

  private remotesUrl = '/janice/mcp/api/remote';

  private testRemotes = [
    {
      id: 0, name: 'lab-switches', host: 'mcr.30aea427b684', hardware: 'esp32',
      firmware: '1111111', firmwarePref: 'head', atVersion: true, startedAt: '10min',
      seenAt: '10min'
    },
    {
      id: 1, name: 'lab-sensors', host: 'mcr.30aea4287f40', hardware: 'esp32',
      firmware: '1111111', firmwarePref: 'head', atVersion: true, startedAt: '11min',
      seenAt: '11min'
    },
  ];

  private testResponse = {
    data: [],
    data2: this.testRemotes,
    items: this.testRemotes.length,
    mtime: 1000
  };

  constructor(private http: HttpClient) { }

  getRemotes(): Observable<Remote[]> {
    return this.http.get<RemoteApiResponse>(this.remotesUrl)
      .pipe(
        map(resp => resp.data2),
        // tap(remotes => console.log(`fetched remotes`)),
        catchError(this.handleError('getRemotes', []))
      );
  }

  private handleError<T>(operation = 'operation', result?: T) {
    return (error: any): Observable<T> => {

      // TODO: send the error to remote logging infrastructure
      console.error(error); // log to console instead

      // TODO: better job of transforming error for user consumption
      console.log(`${operation} failed: ${error.message}`);

      // Let the app keep running by returning an empty result.
      return of(result as T);
    };

  }
}
