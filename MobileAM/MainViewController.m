//
//  ViewController.m
//  Activity Monitor
//
//  Created by vsnRain on 26.11.2012.
//  Copyright (c) 2012 vsnRain. All rights reserved.
//

#import "MainViewController.h"
#import "NSTask.h"

@interface MainViewController (){
    ProcessListHeaderView *headerView;
    BOOL bottomViewActivated;
    
    NSArray *processList;
    
    NSTimer *updateTimer;
    NSTimer *memTimer;
    
    NSInteger selectedPid;
    
    Engine *eng;
}

@end

@implementation MainViewController

- (void) addToLog:(NSString*)string{
    self.log.text=[NSString stringWithFormat:@"%@\n%@",self.log.text, string];
    [self.log scrollRangeToVisible:NSMakeRange(self.log.text.length, 0)];
}

- (void)viewDidLoad{
    [super viewDidLoad];

    // TOP BAR
    self.topBar.delegate = self;
    self.topBar.topItem.title = @"Activity Monitor";
    
    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 240, 64)];
    UIBarButtonItem *searchButton = [[UIBarButtonItem alloc]initWithCustomView:searchBar];
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:searchButton, nil];
    
    // TABLE VIEW
    self.tableView.contentInset = UIEdgeInsetsMake(64, 0, 44, 0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(64, 0, 44, 0);
    
    headerView = [[[NSBundle mainBundle] loadNibNamed:@"ProcessListHeader" owner:self options:nil] objectAtIndex:0];
    headerView.pidButton.backgroundColor = [UIColor colorWithRed:20/255.f green:125/255.f blue:250/255.f alpha:1];
    headerView.sortType = SORT_PID;
    headerView.sortOrderAscending = YES;
    
    [self.tableView registerNib:[UINib nibWithNibName:@"ProcessListCell" bundle:nil] forCellReuseIdentifier:@"ProcessListCellID"];
    
    // BOTTOM VIEW
    self.bottomView.hidden = YES;
    bottomViewActivated = NO;
    [self.view addSubview:self.bottomView];
    
    // OTHER
    [self.bottomView addSubview: self.log];
    [self.bottomView addSubview: self.procView];
    [self.bottomView addSubview: self.memView];
    
    self.procView.backgroundColor = [UIColor clearColor];
    self.procView.hidden = NO;
    
    self.memView.backgroundColor = [UIColor clearColor];
    self.memView.frame = CGRectMake(0, 0, 800, 157);
    self.memView.hidden = YES;
    
    self.log.frame = CGRectMake(20, 20, 730, 120);
    self.log.hidden = YES;
    
    // TABLE DATA
    processList = [[NSArray alloc] init];
    selectedPid = 0;
    
    eng = [[Engine alloc] init];
    Engine.log = self.log;
    
    updateTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
    [self refresh];
}

- (void) viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [self.tableView setNeedsLayout];
}

- (void)viewWillLayoutSubviews{
    
    if (bottomViewActivated){
        self.bottomViewConstraint.constant = self.view.frame.size.height*0.20;
    }else{
        self.bottomViewConstraint.constant = 0;
    }
    
    [self.tableView setNeedsUpdateConstraints];
    [self.bottomToolbar setNeedsUpdateConstraints];
    [self.bottomView setNeedsUpdateConstraints];
}

- (UIBarPosition) positionForBar:(id <UIBarPositioning>)bar {
    return UIBarPositionTopAttached;
}

- (BOOL) prefersStatusBarHidden {
    return NO;
}

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation{
    return YES;
}

- (void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//////////////////////////////////////////////////// TABLEVIEW ///////////////////////////////////////////////////////////////


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    ProcessListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ProcessListCellID"];
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    if(indexPath.row%2==0) cell.contentView.backgroundColor = [UIColor whiteColor];
    else cell.contentView.backgroundColor = [UIColor colorWithRed:245/255.f green:245/255.f blue:250/255.f alpha:1];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(ProcessListCell *)cell forRowAtIndexPath:(nonnull NSIndexPath *)indexPath{
    
    int pidValue = [[[processList objectAtIndex:indexPath.row] objectForKey:@"PID"] intValue];
    NSString *comValue = [[processList objectAtIndex:indexPath.row] objectForKey:@"COMM"];
    
    int uidValue = [[[processList objectAtIndex:indexPath.row] objectForKey:@"UID"] intValue];
    char *uidString = user_from_uid(uidValue, 0);
    
    int gidValue = [[[processList objectAtIndex:indexPath.row] objectForKey:@"GID"] intValue];
    char *gidString = group_from_gid(gidValue, 0);
    
    double cpuValue = [[[processList objectAtIndex:indexPath.row] objectForKey:@"TOT_CPU"] floatValue];
    int thrValue = [[[processList objectAtIndex:indexPath.row] objectForKey:@"THREAD_COUNT"] intValue];
    double memValue = [[[processList objectAtIndex:indexPath.row] objectForKey:@"RES_SIZE"] intValue]/(float) 1024*1024 ;
    
    cell.pidLabel.text = [NSString stringWithFormat:@"%d", pidValue];
    cell.comLabel.text = comValue;
    
    if ( (cell.usrLabel.frame.size.width > 80) && (cell.grpLabel.frame.size.width > 80) ){
        cell.usrLabel.text = [NSString stringWithFormat:@"%s (%d)", uidString, uidValue];
        cell.grpLabel.text = [NSString stringWithFormat:@"%s (%d)", gidString, gidValue];
    }else{
        cell.usrLabel.text = [NSString stringWithFormat:@"%d", uidValue];
        cell.grpLabel.text = [NSString stringWithFormat:@"%d", gidValue];
    }
    
    cell.cpuLabel.text = [NSString stringWithFormat:@"%.2f", cpuValue];
    cell.thrLabel.text = [NSString stringWithFormat:@"%d", thrValue];
    cell.memLabel.text = [NSString stringWithFormat:@"%.2f MB", memValue];
    cell.procIcon.image = [UIImage imageNamed:@"Icon_Empty.png"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return  36.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) return headerView;
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return  36.0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return processList.count;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSDictionary *p = [processList objectAtIndex:indexPath.row];
    selectedPid = [[p objectForKey:@"PID"] intValue];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////// BUTTONS ////////////////////////////////////////////////////////////////

- (IBAction) bottomButtonPressed:(UIButton *)sender {
    
    void (^openAnimation)() = ^void() {
        self.bottomViewConstraint.constant = self.bottomView.frame.size.height;
        
        [self.tableView setNeedsUpdateConstraints];
        [self.bottomToolbar setNeedsUpdateConstraints];
        [self.bottomView setNeedsUpdateConstraints];
        
        [self.view layoutIfNeeded];
    };
    
    void (^closeAnimation)() = ^void() {
        self.bottomViewConstraint.constant = 0;
        
        [self.tableView setNeedsUpdateConstraints];
        [self.bottomToolbar setNeedsUpdateConstraints];
        [self.bottomView setNeedsUpdateConstraints];
        
        [self.view layoutIfNeeded];
    };
    
    if (sender.selected){
        
        sender.selected = NO;
        bottomViewActivated = NO;
        self.bottomView.hidden = NO;
        
        [UIView animateWithDuration:0.2f animations:closeAnimation completion:nil];
        
    }else{
        
        sender.selected = YES;
        bottomViewActivated = YES;
        self.bottomView.hidden = NO;
        
        [UIView animateWithDuration:0.2f animations:openAnimation completion:nil];
    }
}

- (IBAction) buttonInfo {
    //if([self.tableView indexPathForSelectedRow].row>=processList.count){
    //    [[[UIAlertView alloc] initWithTitle:@"Error" message:@"No process selected" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    //}else{
    //    [self performSegueWithIdentifier:@"INFO_SEGUE" sender:self];
    //}
}

- (IBAction) buttonKill {
    //int pid = [[[processList objectAtIndex:[self.tableView indexPathForSelectedRow].row] objectForKey:@"PID"] intValue];
    int pid = (int)selectedPid;
    NSString *msg = [NSString stringWithFormat:@"PID: %d", pid];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleActionSheet];
    alertController.popoverPresentationController.barButtonItem = self.killButton;
    
    void (^killActionBlock)(int signal) = ^void(int signal){
        
        UIAlertController *errorAlertController = [UIAlertController alertControllerWithTitle:@"Error" message:@"" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
        [errorAlertController addAction:cancelAction];
        
        NSIndexPath *selectedPath = [self.tableView indexPathForSelectedRow];
        if (selectedPath == nil) {
            errorAlertController.message = @"No process selected";
            [self presentViewController:errorAlertController animated:YES completion:nil];
            return;
        }
        
        int ret = 0;
        ret = kill(pid, signal);
        
        if(ret != 0){
            NSString *errorString = [NSString stringWithFormat:@"Failed to kill process with pid: %d", pid];
            errorAlertController.message = errorString;
            [self presentViewController:errorAlertController animated:YES completion:nil];
            return;
        }
    };
    
    UIAlertAction *hupAction = [UIAlertAction actionWithTitle:@"HUP (1)" style:UIAlertActionStyleDestructive
                                                      handler:^(UIAlertAction *action) {
                                                          killActionBlock(1);
                                                      }];
    UIAlertAction *sigintAction = [UIAlertAction actionWithTitle:@"INT (2)" style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction *action) {
                                                             killActionBlock(2);
                                                         }];
    UIAlertAction *killAction = [UIAlertAction actionWithTitle:@"KILL (9)" style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction *action) {
                                                           killActionBlock(9);
                                                       }];
    UIAlertAction *termAction = [UIAlertAction actionWithTitle:@"TERM (15)" style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction *action) {
                                                           killActionBlock(15);
                                                       }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {}];
    
    [alertController addAction:hupAction];
    [alertController addAction:sigintAction];
    [alertController addAction:killAction];
    [alertController addAction:termAction];
    [alertController addAction:cancelAction];
    [alertController setModalPresentationStyle:UIModalPresentationPopover];
    [self presentViewController:alertController animated:YES completion:nil];
    
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////// PPOCESS LIST ////////////////////////////////////////////////////////////

- (void) refresh{
    dispatch_queue_t refreshQueue = dispatch_queue_create("Data Refresh", NULL);
    dispatch_async(refreshQueue, ^{
        
#ifdef THEOS
        [eng getProcs];
        processList = eng.proc;
#else
        NSMutableDictionary *sampleProcess = [[NSMutableDictionary alloc] init];
        [sampleProcess setObject:[NSNumber numberWithInt:12345] forKey:@"PID"];
        [sampleProcess setObject:[NSNumber numberWithInt:500] forKey:@"UID"];
        [sampleProcess setObject:[NSNumber numberWithInt:500] forKey:@"GID"];
        [sampleProcess setObject:@"Sample Process" forKey:@"COMM"];
        [sampleProcess setObject:[NSNumber numberWithInt:16] forKey:@"TOT_CPU"];
        [sampleProcess setObject:[NSNumber numberWithInt:3] forKey:@"THREAD_COUNT"];
        [sampleProcess setObject:[NSNumber numberWithInt:3096000] forKey:@"RES_SIZE"];
        processList = [NSArray arrayWithObjects:[sampleProcess copy], [sampleProcess copy], [sampleProcess copy], nil];
#endif
        processList = [processList sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
            SortType sortType = headerView.sortType;
            BOOL sortOrderAscending = headerView.sortOrderAscending;
            
            if ((sortType == SORT_PID) && sortOrderAscending) return [[a objectForKey:@"PID"] compare:[b objectForKey:@"PID"]];
            else if ((sortType == SORT_PID) && !sortOrderAscending) return [[b objectForKey:@"PID"] compare:[a objectForKey:@"PID"]];
            
            else if ((sortType == SORT_COM) && sortOrderAscending) return [[[a objectForKey:@"COMM"] lowercaseString] compare:[[b objectForKey:@"COMM"] lowercaseString]];
            else if ((sortType == SORT_COM) && !sortOrderAscending) return [[[b objectForKey:@"COMM"] lowercaseString] compare:[[a objectForKey:@"COMM"] lowercaseString]];
            
            else if ((sortType == SORT_USR) && sortOrderAscending) return [[a objectForKey:@"UID"] compare:[b objectForKey:@"UID"]];
            else if ((sortType == SORT_PID) && !sortOrderAscending) return [[b objectForKey:@"UID"] compare:[a objectForKey:@"UID"]];
            
            else if ((sortType == SORT_GRP) && sortOrderAscending) return [[a objectForKey:@"GID"] compare:[b objectForKey:@"GID"]];
            else if ((sortType == SORT_GRP) && !sortOrderAscending) return [[b objectForKey:@"GID"] compare:[a objectForKey:@"GID"]];
            
            else if ((sortType == SORT_CPU) && sortOrderAscending) return [[a objectForKey:@"TOT_CPU"] compare:[b objectForKey:@"TOT_CPU"]];
            else if ((sortType == SORT_CPU) && !sortOrderAscending) return [[b objectForKey:@"TOT_CPU"] compare:[a objectForKey:@"TOT_CPU"]];
            
            else if ((sortType == SORT_THR) && sortOrderAscending) return [[a objectForKey:@"THREAD_COUNT"] compare:[b objectForKey:@"THREAD_COUNT"]];
            else if ((sortType == SORT_THR) && !sortOrderAscending) return [[b objectForKey:@"THREAD_COUNT"] compare:[a objectForKey:@"THREAD_COUNT"]];
            
            else if ((sortType == SORT_MEM) && sortOrderAscending) return [[a objectForKey:@"RES_SIZE"] compare:[b objectForKey:@"RES_SIZE"]];
            else if ((sortType == SORT_MEM) && !sortOrderAscending) return [[b objectForKey:@"RES_SIZE"] compare:[a objectForKey:@"RES_SIZE"]];
            
            else return [[a objectForKey:@"PID"] compare:[b objectForKey:@"PID"]];
        }];
        
        NSIndexPath *index;
        for (int i = 0; i < processList.count; i++) {
            NSDictionary *p = [processList objectAtIndex:i];
            NSInteger pid = [[p objectForKey:@"PID"] intValue];
            
            if (pid == selectedPid){
                index = [NSIndexPath indexPathForRow:i inSection:0];
                break;
            }
        }
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            [self.tableView reloadData];
            [self.tableView selectRowAtIndexPath:index animated:NO scrollPosition:0];
            
            //self.cpuLabel.text = [[eng.sys objectForKey:@"SYS_CPU"] stringValue];
            //self.procLabel.text = [[NSNumber numberWithUnsignedLong:processList.count] stringValue];
            //self.thrLabel.text = [[eng.sys objectForKey:@"TOT_THR"] stringValue];
            
            //NSLog(@"Data reloaded");
        });
    });
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void) getMem{
    [eng getMem];
    
    //=========== MEMORY ===============//
    self.pagesize.text = [NSString stringWithFormat:@"%@ B", [eng.mem objectForKey:@"PAGESIZE"]];
    self.physical.text = [NSString stringWithFormat:@"%@ B", [[eng.mem objectForKey:@"PHYS_B"] stringValue]];
    self.user.text = [NSString stringWithFormat:@"%@ B", [[eng.mem objectForKey:@"USER_B"] stringValue]];
    
    self.totalPages.text = [NSString stringWithFormat:@"%d pages", [[eng.mem objectForKey:@"TOTAL"] intValue]];
    self.wiredPages.text = [NSString stringWithFormat:@"%d pages", [[eng.mem objectForKey:@"WIRED"] intValue]];
    self.activePages.text = [NSString stringWithFormat:@"%d pages", [[eng.mem objectForKey:@"ACTIVE"] intValue]];
    self.inactivePages.text = [NSString stringWithFormat:@"%d pages", [[eng.mem objectForKey:@"INACTIVE"] intValue]];
    self.freePages.text = [NSString stringWithFormat:@"%d pages", [[eng.mem objectForKey:@"FREE"] intValue]];
    
    int pagesize = [[eng.mem objectForKey:@"PAGESIZE"] intValue];
    
    self.totalBytes.text = [NSString stringWithFormat:@"%d B", [[eng.mem objectForKey:@"TOTAL"] intValue]*pagesize];
    self.wiredBytes.text = [NSString stringWithFormat:@"%d B", [[eng.mem objectForKey:@"WIRED"] intValue]*pagesize];
    self.activeBytes.text = [NSString stringWithFormat:@"%d B", [[eng.mem objectForKey:@"ACTIVE"] intValue]*pagesize];
    self.inactiveBytes.text = [NSString stringWithFormat:@"%d B", [[eng.mem objectForKey:@"INACTIVE"] intValue]*pagesize];
    self.freeBytes.text = [NSString stringWithFormat:@"%d B", [[eng.mem objectForKey:@"FREE"] intValue]*pagesize];
    
    float total = [[eng.mem objectForKey:@"TOTAL"] intValue];
    
    self.wiredPrc.text = [NSString stringWithFormat:@"%.2f %%", ([[eng.mem objectForKey:@"WIRED"] intValue]/total)*100];
    self.activePrc.text = [NSString stringWithFormat:@"%.2f %%", ([[eng.mem objectForKey:@"ACTIVE"] intValue]/total)*100];
    self.inactivePrc.text = [NSString stringWithFormat:@"%.2f %%", ([[eng.mem objectForKey:@"INACTIVE"] intValue]/total)*100];
    self.freePrc.text = [NSString stringWithFormat:@"%.2f %%", ([[eng.mem objectForKey:@"FREE"] intValue]/total)*100];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@end
