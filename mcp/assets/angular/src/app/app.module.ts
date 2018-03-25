import { BrowserModule } from '@angular/platform-browser';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';
import { NgModule } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Angular2FontawesomeModule } from 'angular2-fontawesome/angular2-fontawesome';

import { ButtonModule } from 'primeng/primeng';
import { ConfirmDialogModule } from 'primeng/confirmdialog';
import { InputTextModule } from 'primeng/inputtext';
import { MenuModule } from 'primeng/menu';
import { MenubarModule } from 'primeng/menubar';
import { TableModule } from 'primeng/table';

import { AppComponent } from './app.component';
import { RemoteTableComponent } from './remotes/remote-table.component';
import { RemoteService } from './remotes/remote.service';
import { AppRoutingModule } from './/app-routing.module';
import { LandingComponent } from './landing/landing.component';
import { SubsystemsComponent } from './subsystems/subsystems.component';
import { RemotesComponent } from './remotes/remotes.component';


@NgModule({
  declarations: [
    AppComponent,
    RemoteTableComponent,
    LandingComponent,
    SubsystemsComponent,
    RemotesComponent
  ],
  imports: [
    BrowserModule,
    BrowserAnimationsModule,
    Angular2FontawesomeModule,
    InputTextModule,
    ButtonModule,
    ConfirmDialogModule,
    FormsModule,
    MenuModule,
    MenubarModule,
    TableModule,
    AppRoutingModule
  ],
  providers: [RemoteService],
  bootstrap: [AppComponent]
})
export class AppModule { }
