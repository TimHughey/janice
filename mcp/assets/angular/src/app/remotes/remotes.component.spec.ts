import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { RemotesComponent } from './remotes.component';

describe('RemotesComponent', () => {
  let component: RemotesComponent;
  let fixture: ComponentFixture<RemotesComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ RemotesComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(RemotesComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
