# IMPLEMENTATION PLAN FOR CODE OPTIMIZATION
## Step-by-Step Guide for Claude Code

**Project:** RAW Focus/Productivity Application
**Total Issues:** 127 identified issues
**Estimated Total Time:** 17-25 weeks
**Approach:** Phased implementation with testing after each phase

---

## IMPORTANT PRINCIPLES

### Throughout All Implementation:
1. **Preserve Functionality** - Never break existing features
2. **Test After Each Change** - Run `flutter analyze` and test manually
3. **Commit Frequently** - Small, atomic commits with clear messages
4. **Backup Before Major Changes** - Create backup branches for risky refactors
5. **One Issue at a Time** - Don't mix multiple fixes in one commit
6. **Verify Fixes** - Test that the fix actually solves the problem

---

## PHASE 1: CRITICAL SECURITY & BUGS (4-5 weeks)
**Priority:** MUST FIX BEFORE LAUNCH
**Goal:** Make app secure and stable

### Week 1: Security Rules & Authorization

#### Task 1.1: Fix Firestore Security Rules
- **File:** `/home/user/raw/firestore.rules`
- **Current Issue:** `allow read, write: if true;` allows unrestricted access
- **Steps:**
  1. Read current firestore.rules
  2. Create new rules with proper user-based access control
  3. Add rules for users collection (read: public, write: own data only)
  4. Add rules for users/{userId}/friends (read/write: owner only)
  5. Add rules for users/{userId}/projects (read/write: owner only)
  6. Add rules for users/{userId}/notifications (read/write: owner only)
  7. Add rules for users/{userId}/achievements (read/write: owner only)
  8. Add rules for groups collection (read: members only, write: admins only)
  9. Deploy rules: `firebase deploy --only firestore:rules`
  10. Test with Firebase Emulator
  11. Verify unauthorized access is blocked
- **Expected Result:** Firestore data is protected by proper authorization rules
- **Commit Message:** "Fix Firestore security rules to restrict access by user ownership"

#### Task 1.2: Add Authorization Checks to UserDataService
- **File:** `/home/user/raw/lib/user_data_service.dart`
- **Steps:**
  1. Read user_data_service.dart
  2. Add _verifyAuthorization method to check current user owns the data
  3. Update loadUserData to verify userId == currentUser.uid
  4. Update saveUserData to verify userId == currentUser.uid
  5. Update deleteUserData to verify userId == currentUser.uid
  6. Add proper exceptions with user-friendly messages
  7. Run flutter analyze
  8. Test with different user accounts
- **Expected Result:** Service methods reject unauthorized access attempts
- **Commit Message:** "Add authorization checks to UserDataService methods"

#### Task 1.3: Add Authorization Checks to FriendsService
- **File:** `/home/user/raw/lib/friends_service.dart`
- **Steps:**
  1. Read friends_service.dart
  2. Add _verifyAuthorization method
  3. Update getFriends to verify userId == currentUser.uid
  4. Update sendFriendRequest to verify userId == currentUser.uid
  5. Update acceptFriendRequest to verify userId == currentUser.uid
  6. Update rejectFriendRequest to verify userId == currentUser.uid
  7. Update removeFriend to verify userId == currentUser.uid
  8. Run flutter analyze
  9. Test friend operations
- **Expected Result:** Friends operations restricted to data owner
- **Commit Message:** "Add authorization checks to FriendsService methods"

#### Task 1.4: Add Authorization Checks to GroupsService
- **File:** `/home/user/raw/lib/groups_service.dart`
- **Steps:**
  1. Read groups_service.dart
  2. Add _verifyGroupMembership method
  3. Add _verifyGroupAdmin method
  4. Update getGroupMembers to verify user is member
  5. Update updateGroup to verify user is admin
  6. Update deleteGroup to verify user is creator
  7. Run flutter analyze
  8. Test group operations
- **Expected Result:** Group operations respect membership and admin roles
- **Commit Message:** "Add authorization checks to GroupsService methods"

#### Task 1.5: Add Authorization Checks to ProjectService
- **File:** `/home/user/raw/lib/project_service.dart`
- **Steps:**
  1. Read project_service.dart
  2. Add _verifyAuthorization method
  3. Update getProjects to verify userId == currentUser.uid
  4. Update createProject to verify userId == currentUser.uid
  5. Update updateProject to verify userId == currentUser.uid
  6. Update deleteProject to verify userId == currentUser.uid
  7. Run flutter analyze
  8. Test project CRUD operations
- **Expected Result:** Project operations restricted to data owner
- **Commit Message:** "Add authorization checks to ProjectService methods"

#### Task 1.6: Add Authorization Checks to NotificationService
- **File:** `/home/user/raw/lib/notification_service.dart`
- **Steps:**
  1. Read notification_service.dart
  2. Add _verifyAuthorization method
  3. Update streamNotifications to verify userId == currentUser.uid
  4. Update markAsRead to verify userId == currentUser.uid
  5. Update markAllAsRead to verify userId == currentUser.uid
  6. Run flutter analyze
  7. Test notification operations
- **Expected Result:** Notification operations restricted to data owner
- **Commit Message:** "Add authorization checks to NotificationService methods"

### Week 2: Memory Leaks & Disposal Issues

#### Task 2.1: Fix Stream Subscription Leak in AuthProvider
- **File:** `/home/user/raw/lib/auth_provider.dart`
- **Lines:** 46-64
- **Steps:**
  1. Read auth_provider.dart
  2. Add `late StreamSubscription<User?> _authSubscription;` field
  3. Store subscription in initState: `_authSubscription = ...listen(...)`
  4. Add dispose method
  5. Cancel subscription in dispose: `_authSubscription.cancel()`
  6. Call super.dispose()
  7. Run flutter analyze
  8. Test auth state changes
  9. Verify no memory leak with DevTools
- **Expected Result:** Auth stream subscription properly cleaned up
- **Commit Message:** "Fix stream subscription memory leak in AuthProvider"

#### Task 2.2: Fix Stream Subscription Leak in FocusFlowAppState
- **File:** `/home/user/raw/lib/main.dart`
- **Line:** 191
- **Steps:**
  1. Read main.dart lines 180-270
  2. Add `late StreamSubscription<User?> _authChangeSubscription;` field
  3. Store subscription in _listenToAuthChanges method
  4. Find or add dispose method in _FocusFlowAppState
  5. Cancel subscription in dispose
  6. Run flutter analyze
  7. Test app lifecycle
  8. Verify no memory leak
- **Expected Result:** Main app auth subscription properly cleaned up
- **Commit Message:** "Fix stream subscription memory leak in main app state"

#### Task 2.3: Fix TextEditingController Leak in _showAddFriendDialog
- **File:** `/home/user/raw/lib/main.dart`
- **Line:** 1758
- **Steps:**
  1. Read _showAddFriendDialog method
  2. Find where searchController is created
  3. Add .then() to showDialog to dispose controller
  4. Also dispose in cancel button onPressed
  5. Run flutter analyze
  6. Test opening/closing dialog multiple times
  7. Check memory with DevTools
- **Expected Result:** Controller disposed when dialog closes
- **Commit Message:** "Fix TextEditingController leak in add friend dialog"

#### Task 2.4: Fix TextEditingController Leak in _showCreateGroupDialog
- **File:** `/home/user/raw/lib/main.dart`
- **Line:** 2981
- **Steps:**
  1. Read _showCreateGroupDialog method
  2. Find nameController and descriptionController
  3. Add .then() to showDialog to dispose both controllers
  4. Dispose in cancel button
  5. Run flutter analyze
  6. Test create group dialog
- **Expected Result:** Both controllers disposed properly
- **Commit Message:** "Fix TextEditingController leaks in create group dialog"

#### Task 2.5: Fix TextEditingController Leak in _showJoinGroupDialog
- **File:** `/home/user/raw/lib/main.dart`
- **Line:** 3136
- **Steps:**
  1. Read _showJoinGroupDialog method
  2. Find codeController
  3. Add disposal logic
  4. Run flutter analyze
  5. Test join group dialog
- **Expected Result:** Controller disposed properly
- **Commit Message:** "Fix TextEditingController leak in join group dialog"

#### Task 2.6: Fix TextEditingController Leak in _showChangeUsernameDialog
- **File:** `/home/user/raw/lib/main.dart`
- **Line:** 6366
- **Steps:**
  1. Read _showChangeUsernameDialog method
  2. Find controller
  3. Add disposal logic
  4. Run flutter analyze
  5. Test username change dialog
- **Expected Result:** Controller disposed properly
- **Commit Message:** "Fix TextEditingController leak in change username dialog"

#### Task 2.7: Fix TextEditingController Leak in _showChangeEmailDialog
- **File:** `/home/user/raw/lib/main.dart`
- **Line:** 6449
- **Steps:**
  1. Read _showChangeEmailDialog method
  2. Find emailController and passwordController
  3. Add disposal logic for both
  4. Run flutter analyze
  5. Test email change dialog
- **Expected Result:** Both controllers disposed properly
- **Commit Message:** "Fix TextEditingController leaks in change email dialog"

#### Task 2.8: Fix TextEditingController Leak in _showChangePasswordDialog
- **File:** `/home/user/raw/lib/main.dart`
- **Line:** 6549
- **Steps:**
  1. Read _showChangePasswordDialog method
  2. Find all TextEditingControllers
  3. Add disposal logic
  4. Run flutter analyze
  5. Test password change dialog
- **Expected Result:** All controllers disposed properly
- **Commit Message:** "Fix TextEditingController leaks in change password dialog"

### Week 3: Null Safety & Error Handling

#### Task 3.1: Fix Force Unwrapping in FriendsService
- **File:** `/home/user/raw/lib/friends_service.dart`
- **Line:** 86
- **Steps:**
  1. Read friends_service.dart line 86
  2. Replace `docSnapshot.data()!` with null check
  3. Add proper error handling if data is null
  4. Add similar fixes to all force unwraps in the file
  5. Run flutter analyze
  6. Test with missing user documents
- **Expected Result:** No crashes from null pointer exceptions
- **Commit Message:** "Fix force unwrapping in FriendsService with proper null checks"

#### Task 3.2: Fix Force Unwrapping in Main.dart
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 2899, 3410-3412
- **Steps:**
  1. Search for all `!` operators in main.dart
  2. For each force unwrap, add null check before use
  3. Add fallback values or error handling
  4. Run flutter analyze
  5. Test affected screens
- **Expected Result:** No force unwrap crashes
- **Commit Message:** "Fix force unwrapping in main.dart with proper null checks"

#### Task 3.3: Add Mounted Checks Before setState
- **File:** `/home/user/raw/lib/main.dart`
- **Multiple locations:** 1912, 1930, etc.
- **Steps:**
  1. Search for all async methods that call setState
  2. Add `if (!mounted) return;` before each setState
  3. Search for ScaffoldMessenger after async operations
  4. Add mounted checks before ScaffoldMessenger calls
  5. Run flutter analyze
  6. Test rapid navigation and async operations
- **Expected Result:** No "setState after dispose" errors
- **Commit Message:** "Add mounted checks before setState and ScaffoldMessenger calls"

#### Task 3.4: Add Missing Dispose Methods
- **File:** `/home/user/raw/lib/main.dart`
- **Screens:** ProfileScreen, FocusScreen, CommunityScreen, GroupDetailsScreen
- **Steps:**
  1. Find ProfileScreen class (line ~3867)
  2. Check if dispose method exists
  3. Add dispose method if missing
  4. Dispose _scrollController
  5. Repeat for FocusScreen (dispose _timer)
  6. Repeat for CommunityScreen (dispose scroll controllers)
  7. Repeat for GroupDetailsScreen (dispose controllers)
  8. Run flutter analyze
  9. Test screen navigation
- **Expected Result:** All controllers properly disposed
- **Commit Message:** "Add missing dispose methods to all screen widgets"

### Week 4: Input Validation

#### Task 4.1: Add Email Validation
- **File:** `/home/user/raw/lib/signup_screen.dart`
- **Line:** 872
- **Steps:**
  1. Read signup_screen.dart
  2. Create _isValidEmail method with regex validation
  3. Update email field validation to use _isValidEmail
  4. Add user-friendly error messages
  5. Also update login_screen.dart with same validation
  6. Run flutter analyze
  7. Test with invalid emails
- **Expected Result:** Invalid emails rejected with clear error
- **Commit Message:** "Add email validation to signup and login screens"

#### Task 4.2: Add Username Validation
- **File:** `/home/user/raw/lib/signup_screen.dart`
- **Line:** 880
- **Steps:**
  1. Create _isValidUsername method
  2. Check length (3-20 characters)
  3. Check allowed characters (alphanumeric + underscore)
  4. Add _checkUsernameAvailability method
  5. Query Firestore to check if username exists
  6. Update username field validation
  7. Add debouncing for availability check
  8. Run flutter analyze
  9. Test with invalid and duplicate usernames
- **Expected Result:** Only valid, unique usernames accepted
- **Commit Message:** "Add username validation with uniqueness check"

#### Task 4.3: Add Age/Birthday Validation
- **File:** `/home/user/raw/lib/signup_screen.dart`
- **Line:** 888
- **Steps:**
  1. Create _isValidAge method
  2. Calculate age from birthday
  3. Require age >= 13 (COPPA compliance)
  4. Require age <= 120 (reasonable max)
  5. Ensure date is in the past
  6. Update birthday field validation
  7. Add clear error messages
  8. Run flutter analyze
  9. Test with invalid dates
- **Expected Result:** Only valid birthdates accepted
- **Commit Message:** "Add birthday validation with COPPA age requirement"

#### Task 4.4: Add General Input Sanitization
- **Files:** `/home/user/raw/lib/signup_screen.dart`, `/home/user/raw/lib/main.dart`
- **Steps:**
  1. Create utility class for input sanitization
  2. Add sanitizeString method (trim, remove special chars)
  3. Add validateStringLength method
  4. Apply to all user input fields (name, description, etc.)
  5. Add to group creation, profile editing
  6. Run flutter analyze
  7. Test with malicious inputs
- **Expected Result:** All user inputs sanitized before storage
- **Commit Message:** "Add input sanitization for all user-facing forms"

### Week 5: Remove Test Code & Security Issues

#### Task 5.1: Remove Test Users Screen
- **File:** `/home/user/raw/lib/test_users_screen.dart`
- **Steps:**
  1. Delete test_users_screen.dart file
  2. Find references in main.dart (line ~339)
  3. Remove debug screen link from main app
  4. Remove import statement
  5. Run flutter analyze
  6. Test that debug screen is gone
  7. Verify app still runs
- **Expected Result:** Test screen completely removed
- **Commit Message:** "Remove test users screen and hardcoded credentials"

#### Task 5.2: Add Email Verification Flow
- **File:** `/home/user/raw/lib/signup_screen.dart`
- **Line:** 997-1003
- **Steps:**
  1. Read signup flow around line 997
  2. Create email_verification_screen.dart file
  3. After createUserWithEmailAndPassword, send verification email
  4. Navigate to EmailVerificationScreen instead of auto-login
  5. Add periodic check for email verification
  6. Only allow login after verification
  7. Add resend verification email button
  8. Run flutter analyze
  9. Test complete signup flow
- **Expected Result:** Users must verify email before using app
- **Commit Message:** "Add email verification requirement for new signups"

#### Task 5.3: Remove TODOs and Production Comments
- **Files:** All files
- **Steps:**
  1. Search codebase for "TODO: FOR RELEASE"
  2. Either implement the TODO or remove it
  3. Search for debug comments
  4. Remove or implement features marked as incomplete
  5. Run flutter analyze
  6. Test affected areas
- **Expected Result:** No production-critical TODOs remain
- **Commit Message:** "Remove or implement production-critical TODOs"

---

## PHASE 2: CRITICAL PERFORMANCE (3-4 weeks)
**Priority:** MUST FIX FOR SCALABILITY
**Goal:** Make app performant at scale

### Week 6: Fix Critical Algorithm Issues

#### Task 6.1: Fix O(n²) Algorithm in updateFriendStats
- **File:** `/home/user/raw/lib/groups_service.dart`
- **Lines:** 278-313
- **Steps:**
  1. Read updateFriendStats method
  2. Understand current implementation (loads all users, queries each)
  3. Design new approach: maintain friends list in user document
  4. Create data migration script for existing data
  5. Update friend request acceptance to add friendId to user's friends array
  6. Rewrite updateFriendStats to use friends array (1 query instead of N+1)
  7. Use batch writes for efficiency
  8. Run flutter analyze
  9. Test with Firebase Emulator
  10. Measure performance improvement
  11. Run data migration on production
- **Expected Result:** 1,001 queries → 1 query for 1,000 users
- **Commit Message:** "Fix O(n²) algorithm in updateFriendStats with reverse index"

#### Task 6.2: Fix N+1 Query in getFriends
- **File:** `/home/user/raw/lib/friends_service.dart`
- **Lines:** 138-161
- **Steps:**
  1. Read getFriends method
  2. Note current implementation (1 query + N queries)
  3. Rewrite to batch load user documents
  4. Extract friend IDs from first query
  5. Use whereIn query with chunks of 10 (Firestore limit)
  6. Combine results into Friend objects
  7. Run flutter analyze
  8. Test friend list loading
  9. Measure performance: should be 6 queries instead of 51 for 50 friends
- **Expected Result:** 51 queries → 6 queries, 5 seconds → 500ms
- **Commit Message:** "Fix N+1 query problem in getFriends with batched reads"

#### Task 6.3: Fix N+1 Query in getGroupMembers
- **File:** `/home/user/raw/lib/groups_service.dart`
- **Lines:** 216-245
- **Steps:**
  1. Read getGroupMembers method
  2. Apply same batching pattern as getFriends
  3. Extract member IDs
  4. Batch load user documents with whereIn
  5. Run flutter analyze
  6. Test group member loading
  7. Measure performance improvement
- **Expected Result:** 21 queries → 3 queries for 20 members
- **Commit Message:** "Fix N+1 query problem in getGroupMembers with batched reads"

### Week 7: Firestore Indexes & Query Optimization

#### Task 7.1: Create Firestore Indexes File
- **File:** Create `/home/user/raw/firestore.indexes.json`
- **Steps:**
  1. Create new file firestore.indexes.json
  2. Add index for friends collection (status + createdAt)
  3. Add index for notifications collection (read + createdAt)
  4. Add index for groups collection (memberIds + createdAt)
  5. Add any other composite indexes needed
  6. Deploy: `firebase deploy --only firestore:indexes`
  7. Wait for indexes to build (5-30 minutes)
  8. Test queries that needed indexes
  9. Verify queries work without "requires an index" error
- **Expected Result:** All compound queries have required indexes
- **Commit Message:** "Add Firestore composite indexes for optimized queries"

#### Task 7.2: Add Search Debouncing
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 1799-1842 (_showAddFriendDialog)
- **Steps:**
  1. Read _showAddFriendDialog method
  2. Convert to StatefulWidget if it's a function
  3. Add Timer? _debounce field
  4. Implement _onSearchChanged method
  5. Cancel previous timer before starting new one
  6. Only execute search after 500ms of no typing
  7. Dispose timer in dispose method
  8. Run flutter analyze
  9. Test search typing "flutter" - should only query once
- **Expected Result:** 7 queries → 1 query when typing
- **Commit Message:** "Add search debouncing to reduce Firestore queries"

#### Task 7.3: Add Pagination to Friends List
- **File:** `/home/user/raw/lib/friends_service.dart`
- **Steps:**
  1. Read getFriends method
  2. Add optional limit parameter (default 50)
  3. Add optional startAfter parameter for pagination
  4. Update query to use limit and startAfter
  5. Update UI to implement pagination
  6. Add "Load More" button or infinite scroll
  7. Run flutter analyze
  8. Test loading friends in pages
- **Expected Result:** Only load 50 friends at a time instead of all
- **Commit Message:** "Add pagination to friends list for better performance"

#### Task 7.4: Add Pagination to Group Members
- **File:** `/home/user/raw/lib/groups_service.dart`
- **Steps:**
  1. Read getGroupMembers method
  2. Add pagination parameters
  3. Update query
  4. Update UI
  5. Run flutter analyze
  6. Test group member loading
- **Expected Result:** Load members in pages
- **Commit Message:** "Add pagination to group members list"

### Week 8: Real-Time Sync & Image Optimization

#### Task 8.1: Implement Real-Time User Data Sync
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 189-261
- **Steps:**
  1. Read _listenToAuthChanges method
  2. Replace loadUserData with streamUserData
  3. Store StreamSubscription for user data
  4. Update state when stream emits new data
  5. Cancel previous subscription when user changes
  6. Dispose subscription in dispose method
  7. Run flutter analyze
  8. Test with two devices logged in as same user
  9. Verify changes on one device appear on other
- **Expected Result:** Real-time data synchronization across devices
- **Commit Message:** "Implement real-time user data synchronization with Firestore streams"

#### Task 8.2: Add Image Size Constraints
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 4028-4040 (ProfileScreen), and all other images
- **Steps:**
  1. Search for all CachedNetworkImage widgets
  2. Add maxWidth: 400, maxHeight: 400 to each
  3. Add memCacheWidth: 400, memCacheHeight: 400
  4. Add placeholder and errorWidget
  5. Run flutter analyze
  6. Test image loading
  7. Verify memory usage reduction with DevTools
- **Expected Result:** 50MB → 1MB per image, 98% memory reduction
- **Commit Message:** "Add image size constraints to reduce memory usage"

#### Task 8.3: Optimize Profile Image Upload
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 6715-6748 (AccountSettingsScreen)
- **Steps:**
  1. Read image upload code
  2. Add image compression before upload
  3. Resize to max 1024x1024
  4. Use image package to compress
  5. Update progress indicator during upload
  6. Run flutter analyze
  7. Test image upload
  8. Measure upload time improvement
- **Expected Result:** Faster uploads, smaller storage usage
- **Commit Message:** "Add image compression before upload to reduce file size"

### Week 9: Widget Rebuild Optimization

#### Task 9.1: Optimize FocusScreen Timer Rebuilds
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 698-1539 (FocusScreen)
- **Steps:**
  1. Read FocusScreen widget
  2. Extract timer display into separate widget (TimerDisplay)
  3. Make TimerDisplay stateless with remainingSeconds parameter
  4. Wrap static widgets in const constructors
  5. Only rebuild TimerDisplay on timer tick
  6. Use RepaintBoundary for expensive widgets
  7. Run flutter analyze
  8. Test timer functionality
  9. Measure frame rate improvement (should be 60 FPS)
- **Expected Result:** 500+ widgets rebuilt → 1 widget rebuilt per second
- **Commit Message:** "Optimize FocusScreen to only rebuild timer display on tick"

#### Task 9.2: Add itemExtent to ListViews
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 5697-5862 (ProfileScreen achievements list)
- **Steps:**
  1. Find all ListView.builder instances
  2. Measure typical item height
  3. Add itemExtent parameter with fixed height
  4. Wrap list items in SizedBox with same height
  5. Run flutter analyze
  6. Test list scrolling
  7. Verify smoother scrolling performance
- **Expected Result:** Better scroll performance, 60 FPS scrolling
- **Commit Message:** "Add itemExtent to ListViews for better scroll performance"

#### Task 9.3: Parallelize Profile Screen Data Loading
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 4472-4508 (_refreshProfile)
- **Steps:**
  1. Read _refreshProfile method
  2. Replace sequential awaits with Future.wait
  3. Load userData, projects, achievements in parallel
  4. Extract results from Future.wait array
  5. Update state once with all data
  6. Run flutter analyze
  7. Test profile refresh
  8. Measure time: should be 300ms instead of 700ms
- **Expected Result:** 700ms → 300ms, 2.3x faster
- **Commit Message:** "Parallelize data loading in ProfileScreen for faster refresh"

#### Task 9.4: Cache Graph Calculations
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 5157-5405 (ProfileScreen graph rendering)
- **Steps:**
  1. Read graph calculation code
  2. Add _cachedGraphData field
  3. Add _cachedPeriodKey field
  4. Create _getGraphData method that caches results
  5. Only recalculate when period changes
  6. Run flutter analyze
  7. Test graph interactions
  8. Verify no redundant calculations
- **Expected Result:** Eliminate redundant graph calculations
- **Commit Message:** "Cache graph calculations to avoid redundant computation"

---

## PHASE 3: ARCHITECTURE REFACTORING (4-6 weeks)
**Priority:** FOR MAINTAINABILITY
**Goal:** Make codebase maintainable and scalable

### Week 10-11: Split main.dart Into Separate Files

#### Task 10.1: Extract FocusScreen to Separate File
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 698-1539
- **Steps:**
  1. Create new file: lib/screens/focus_screen.dart
  2. Copy FocusScreen and _FocusScreenState classes
  3. Add necessary imports
  4. Export FocusScreen from focus_screen.dart
  5. Import focus_screen.dart in main.dart
  6. Remove FocusScreen code from main.dart
  7. Run flutter analyze
  8. Test FocusScreen functionality
  9. Verify no regressions
- **Expected Result:** FocusScreen in separate file
- **Commit Message:** "Extract FocusScreen to separate file for better organization"

#### Task 10.2: Extract CommunityScreen to Separate File
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 1540-3284
- **Steps:**
  1. Create lib/screens/community_screen.dart
  2. Copy CommunityScreen classes
  3. Add imports and exports
  4. Update main.dart import
  5. Remove from main.dart
  6. Run flutter analyze
  7. Test community features
- **Expected Result:** CommunityScreen in separate file
- **Commit Message:** "Extract CommunityScreen to separate file"

#### Task 10.3: Extract GroupDetailsScreen to Separate File
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 3285-3850
- **Steps:**
  1. Create lib/screens/group_details_screen.dart
  2. Copy code
  3. Update imports
  4. Run flutter analyze
  5. Test group details
- **Expected Result:** GroupDetailsScreen in separate file
- **Commit Message:** "Extract GroupDetailsScreen to separate file"

#### Task 10.4: Extract ProfileScreen to Separate File
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 3851-6262
- **Steps:**
  1. Create lib/screens/profile_screen.dart
  2. Copy ProfileScreen (2,411 lines!)
  3. Update imports
  4. Run flutter analyze
  5. Test profile features
- **Expected Result:** ProfileScreen in separate file
- **Commit Message:** "Extract ProfileScreen to separate file"

#### Task 10.5: Extract AccountSettingsScreen to Separate File
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 6263-7121
- **Steps:**
  1. Create lib/screens/settings/account_settings_screen.dart
  2. Copy code
  3. Update imports
  4. Run flutter analyze
  5. Test account settings
- **Expected Result:** AccountSettingsScreen in separate file
- **Commit Message:** "Extract AccountSettingsScreen to settings folder"

#### Task 10.6: Extract NotificationCenterScreen to Separate File
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 7122-7402
- **Steps:**
  1. Create lib/screens/notifications/notification_center_screen.dart
  2. Copy code
  3. Update imports
  4. Run flutter analyze
  5. Test notifications
- **Expected Result:** NotificationCenterScreen in separate file
- **Commit Message:** "Extract NotificationCenterScreen to notifications folder"

#### Task 10.7: Extract SettingsScreen to Separate File
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 7403-8097
- **Steps:**
  1. Create lib/screens/settings/settings_screen.dart
  2. Copy code
  3. Update imports
  4. Run flutter analyze
  5. Test settings navigation
- **Expected Result:** SettingsScreen in separate file
- **Commit Message:** "Extract SettingsScreen to settings folder"

#### Task 10.8: Extract Privacy, Notifications, and About Screens
- **File:** `/home/user/raw/lib/main.dart`
- **Steps:**
  1. Create lib/screens/settings/privacy_screen.dart (lines 8098-8564)
  2. Create lib/screens/settings/notifications_settings_screen.dart (lines 8565-8963)
  3. Create lib/screens/settings/about_screen.dart (lines 8964-9505)
  4. Copy code for each
  5. Update imports
  6. Run flutter analyze
  7. Test all settings screens
- **Expected Result:** All settings screens in separate files
- **Commit Message:** "Extract remaining settings screens to separate files"

#### Task 10.9: Extract MainScreen to Separate File
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 436-695
- **Steps:**
  1. Create lib/widgets/main_screen.dart
  2. Copy MainScreen
  3. Update imports
  4. Run flutter analyze
  5. Test navigation
- **Expected Result:** MainScreen in widgets folder
- **Commit Message:** "Extract MainScreen to widgets folder"

#### Task 10.10: Cleanup main.dart to Only App Initialization
- **File:** `/home/user/raw/lib/main.dart`
- **Steps:**
  1. Verify all screens extracted
  2. main.dart should only contain:
     - main() function
     - FocusFlowApp widget
     - _FocusFlowAppState
     - Provider widgets
  3. Remove all extracted code
  4. Ensure all imports are correct
  5. Run flutter analyze
  6. Test complete app
  7. Verify file is now ~500 lines instead of 9,505
- **Expected Result:** main.dart reduced from 9,505 → ~500 lines
- **Commit Message:** "Cleanup main.dart after extracting all screens - now only app initialization"

### Week 12-13: State Management Refactoring

#### Task 12.1: Remove Duplicate ProfileImageProvider
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 106-130, 179-180
- **Steps:**
  1. Read ProfileImageProvider code
  2. Note where it's used (profile images only)
  3. Remove _profileImagePath and _bannerImagePath fields from _FocusFlowAppState
  4. Update all code to use userData.avatarUrl and userData.bannerImageUrl directly
  5. Remove ProfileImageProvider widget entirely
  6. Update all widgets that accessed ProfileImageProvider
  7. Run flutter analyze
  8. Test profile image display and upload
- **Expected Result:** Single source of truth for images
- **Commit Message:** "Remove duplicate ProfileImageProvider - use UserData fields directly"

#### Task 12.2: Fix updateShouldNotify in UserDataProvider
- **File:** `/home/user/raw/lib/main.dart`
- **Line:** 150
- **Steps:**
  1. Read UserDataProvider.updateShouldNotify
  2. Replace reference equality with field comparison
  3. Compare all relevant fields (email, name, avatarUrl, focusHours, etc.)
  4. Or add equatable package and use it
  5. Run flutter analyze
  6. Test that UI updates when data changes
- **Expected Result:** Proper update detection for nested changes
- **Commit Message:** "Fix updateShouldNotify to use field comparison instead of reference equality"

#### Task 12.3: Add Rollback on Failed Saves
- **File:** `/home/user/raw/lib/main.dart`
- **Lines:** 265-283
- **Steps:**
  1. Read _updateUserData method
  2. Store previous UserData before updating
  3. Add try-catch around save operation
  4. On error, rollback setState to previous data
  5. Show SnackBar error message to user
  6. Run flutter analyze
  7. Test by simulating Firestore failure
- **Expected Result:** Failed saves don't leave inconsistent state
- **Commit Message:** "Add rollback mechanism for failed user data saves"

#### Task 12.4: Install and Setup Provider Package
- **File:** `/home/user/raw/pubspec.yaml`
- **Steps:**
  1. Add provider package: `provider: ^6.1.1`
  2. Run flutter pub get
  3. Create lib/providers/auth_provider.dart (ChangeNotifier)
  4. Create lib/providers/user_data_provider.dart (ChangeNotifier)
  5. Create lib/providers/project_provider.dart (ChangeNotifier)
  6. Migrate logic from InheritedWidgets to ChangeNotifiers
  7. Wrap app with MultiProvider in main.dart
  8. Run flutter analyze
  9. Test basic functionality
- **Expected Result:** Modern state management with Provider
- **Commit Message:** "Setup Provider package for better state management"

#### Task 12.5: Migrate to Provider Pattern Throughout App
- **Files:** All screen files
- **Steps:**
  1. Update FocusScreen to use Provider.of or Consumer
  2. Update CommunityScreen
  3. Update ProfileScreen
  4. Update all settings screens
  5. Remove old InheritedWidget code
  6. Run flutter analyze
  7. Test all features
  8. Verify no regressions
- **Expected Result:** Consistent Provider usage, no prop drilling
- **Commit Message:** "Migrate all screens to use Provider for state management"

### Week 14-15: Service Layer Improvements

#### Task 14.1: Create FocusSessionService
- **File:** Create `/home/user/raw/lib/services/focus_session_service.dart`
- **Steps:**
  1. Create new service file
  2. Extract focus session business logic from FocusScreen
  3. Create completeFocusSession method
  4. Move session calculations to service
  5. Move achievement checking to service
  6. Update FocusScreen to use service
  7. Run flutter analyze
  8. Test focus sessions
- **Expected Result:** Business logic separated from UI
- **Commit Message:** "Create FocusSessionService to separate business logic from UI"

#### Task 14.2: Create Repository Pattern Base Classes
- **File:** Create `/home/user/raw/lib/repositories/base_repository.dart`
- **Steps:**
  1. Create abstract UserRepository interface
  2. Define methods: get, save, delete, stream
  3. Create FirestoreUserRepository implementation
  4. Create abstract FriendsRepository interface
  5. Create FirestoreFriendsRepository implementation
  6. Create abstract GroupsRepository interface
  7. Create FirestoreGroupsRepository implementation
  8. Run flutter analyze
- **Expected Result:** Abstraction layer for data access
- **Commit Message:** "Add repository pattern for data access abstraction"

#### Task 14.3: Update Services to Use Repositories
- **Files:** All service files
- **Steps:**
  1. Update UserDataService to use UserRepository
  2. Update FriendsService to use FriendsRepository
  3. Update GroupsService to use GroupsRepository
  4. Add dependency injection for repositories
  5. Run flutter analyze
  6. Test all features
- **Expected Result:** Services decoupled from Firestore
- **Commit Message:** "Update services to use repository pattern"

#### Task 14.4: Add Caching Layer
- **File:** Create `/home/user/raw/lib/repositories/cached_user_repository.dart`
- **Steps:**
  1. Create CachedUserRepository that wraps FirestoreUserRepository
  2. Add in-memory cache with TTL
  3. Implement cache-first strategy
  4. Add cache invalidation
  5. Update dependency injection to use cached version
  6. Run flutter analyze
  7. Test with network monitoring
  8. Verify reduced Firestore reads
- **Expected Result:** Fewer Firestore queries through caching
- **Commit Message:** "Add caching layer to reduce Firestore queries"

---

## PHASE 4: CODE QUALITY & TESTING (3-4 weeks)
**Priority:** FOR PRODUCTION READINESS
**Goal:** Production-ready with tests and documentation

### Week 16: Constants & Error Handling

#### Task 16.1: Create Constants Files
- **Files:** Create constants directory
- **Steps:**
  1. Create lib/constants/app_colors.dart
  2. Define all color constants used in app
  3. Create lib/constants/app_dimensions.dart
  4. Define padding, margins, border radius
  5. Create lib/constants/app_durations.dart
  6. Define animation and timer durations
  7. Create lib/constants/app_text_styles.dart
  8. Define text styles
  9. Run flutter analyze
- **Expected Result:** All constants centralized
- **Commit Message:** "Create constants files for colors, dimensions, and styles"

#### Task 16.2: Replace Hardcoded Values
- **Files:** All screen files
- **Steps:**
  1. Search for Color(0x...) and replace with AppColors constants
  2. Search for fontSize and replace with AppTextStyles
  3. Search for BorderRadius.circular and replace with AppDimensions
  4. Search for Duration and replace with AppDurations
  5. Run flutter analyze
  6. Test UI
  7. Verify visual appearance unchanged
- **Expected Result:** No hardcoded values in UI code
- **Commit Message:** "Replace hardcoded values with constants throughout app"

#### Task 16.3: Create Custom Exception Classes
- **File:** Create `/home/user/raw/lib/exceptions/app_exceptions.dart`
- **Steps:**
  1. Create AppException base class
  2. Create AuthException subclass
  3. Create DataException subclass
  4. Create NetworkException subclass
  5. Create ValidationException subclass
  6. Each with user-friendly message property
  7. Run flutter analyze
- **Expected Result:** Type-safe exception handling
- **Commit Message:** "Create custom exception classes for better error handling"

#### Task 16.4: Add User-Facing Error Messages
- **Files:** All service files
- **Steps:**
  1. Replace debugPrint with throw CustomException
  2. Update all services to throw proper exceptions
  3. Update UI to catch and display exceptions
  4. Use ScaffoldMessenger to show user-friendly errors
  5. Add error logging (but still show user messages)
  6. Run flutter analyze
  7. Test error scenarios
  8. Verify user sees helpful messages
- **Expected Result:** Users informed of errors, not silent failures
- **Commit Message:** "Add user-facing error messages with custom exceptions"

### Week 17: Unit Tests

#### Task 17.1: Setup Testing Infrastructure
- **File:** `/home/user/raw/pubspec.yaml`
- **Steps:**
  1. Add test dependencies: mockito, fake_cloud_firestore, flutter_test
  2. Run flutter pub get
  3. Create test directory structure
  4. Create test/models/, test/services/, test/repositories/
  5. Setup mocks and test utilities
  6. Run flutter analyze
- **Expected Result:** Testing infrastructure ready
- **Commit Message:** "Setup testing infrastructure with mockito and test dependencies"

#### Task 17.2: Write UserData Model Tests
- **File:** Create `/home/user/raw/test/models/user_data_test.dart`
- **Steps:**
  1. Create test file
  2. Test toJson/fromJson symmetry
  3. Test copyWith preserves unchanged fields
  4. Test copyWith updates specified fields
  5. Test default values
  6. Test edge cases (empty lists, null values)
  7. Run flutter test
  8. Achieve 100% coverage for UserData
- **Expected Result:** UserData fully tested
- **Commit Message:** "Add comprehensive unit tests for UserData model"

#### Task 17.3: Write Friend and Group Model Tests
- **Files:** Create test/models/friend_test.dart, test/models/group_test.dart
- **Steps:**
  1. Create test files
  2. Test serialization for Friend model
  3. Test serialization for Group model
  4. Test edge cases
  5. Run flutter test
  6. Achieve high coverage
- **Expected Result:** All models tested
- **Commit Message:** "Add unit tests for Friend and Group models"

#### Task 17.4: Write UserDataService Tests
- **File:** Create `/home/user/raw/test/services/user_data_service_test.dart`
- **Steps:**
  1. Create test file
  2. Setup FakeFirebaseFirestore
  3. Test loadUserData success case
  4. Test loadUserData with missing document
  5. Test saveUserData
  6. Test deleteUserData
  7. Test streamUserData
  8. Test authorization checks
  9. Run flutter test
  10. Achieve high coverage
- **Expected Result:** UserDataService fully tested
- **Commit Message:** "Add comprehensive tests for UserDataService"

#### Task 17.5: Write FriendsService Tests
- **File:** Create `/home/user/raw/test/services/friends_service_test.dart`
- **Steps:**
  1. Create test file
  2. Test sendFriendRequest
  3. Test acceptFriendRequest
  4. Test rejectFriendRequest
  5. Test getFriends
  6. Test removeFriend
  7. Test authorization
  8. Run flutter test
- **Expected Result:** FriendsService tested
- **Commit Message:** "Add tests for FriendsService"

#### Task 17.6: Write GroupsService and Other Service Tests
- **Files:** Create test files for all services
- **Steps:**
  1. Test GroupsService
  2. Test ProjectService
  3. Test NotificationService
  4. Test AchievementsService
  5. Run flutter test
  6. Aim for >80% code coverage
- **Expected Result:** All services tested
- **Commit Message:** "Add tests for all remaining services"

### Week 18: Widget & Integration Tests

#### Task 18.1: Write FocusScreen Widget Tests
- **File:** Create `/home/user/raw/test/screens/focus_screen_test.dart`
- **Steps:**
  1. Create test file
  2. Test initial state (timer at 60:00)
  3. Test start button appears
  4. Test timer countdown
  5. Test pause/resume
  6. Test completion flow
  7. Run flutter test
- **Expected Result:** FocusScreen widget tested
- **Commit Message:** "Add widget tests for FocusScreen"

#### Task 18.2: Write ProfileScreen Widget Tests
- **File:** Create `/home/user/raw/test/screens/profile_screen_test.dart`
- **Steps:**
  1. Create test file
  2. Test profile display
  3. Test stats graphs
  4. Test achievement display
  5. Test edit profile flow
  6. Run flutter test
- **Expected Result:** ProfileScreen tested
- **Commit Message:** "Add widget tests for ProfileScreen"

#### Task 18.3: Write Auth Flow Tests
- **Files:** Create test/screens/auth_test.dart
- **Steps:**
  1. Test login screen
  2. Test signup screen
  3. Test email verification
  4. Test auth state changes
  5. Run flutter test
- **Expected Result:** Auth flows tested
- **Commit Message:** "Add widget tests for authentication flows"

#### Task 18.4: Create Integration Tests
- **File:** Create `/home/user/raw/integration_test/app_test.dart`
- **Steps:**
  1. Create integration_test directory
  2. Add integration_test package
  3. Write complete user flow test:
     - Launch app
     - Sign up
     - Complete onboarding
     - Start focus session
     - Complete session
     - View profile
     - Logout
  4. Run integration tests
- **Expected Result:** End-to-end user flow tested
- **Commit Message:** "Add integration tests for complete user flows"

### Week 19: GDPR & Privacy

#### Task 19.1: Implement Account Deletion
- **File:** Create `/home/user/raw/lib/services/account_service.dart`
- **Steps:**
  1. Create AccountService
  2. Implement deleteAccount method
  3. Delete user document from Firestore
  4. Delete all subcollections (friends, projects, etc.)
  5. Delete profile images from Storage
  6. Delete Firebase Auth account
  7. Add confirmation dialog in UI
  8. Add to account settings screen
  9. Run flutter analyze
  10. Test account deletion
- **Expected Result:** Users can delete their accounts
- **Commit Message:** "Implement GDPR-compliant account deletion feature"

#### Task 19.2: Implement Data Export
- **File:** Update `/home/user/raw/lib/services/account_service.dart`
- **Steps:**
  1. Create exportUserData method
  2. Gather all user data (profile, friends, groups, sessions)
  3. Create JSON export
  4. Add download functionality
  5. Add to account settings screen
  6. Run flutter analyze
  7. Test data export
  8. Verify exported JSON is complete
- **Expected Result:** Users can export their data
- **Commit Message:** "Implement GDPR data export functionality"

#### Task 19.3: Create Privacy Policy
- **File:** `/home/user/raw/lib/screens/settings/privacy_screen.dart`
- **Steps:**
  1. Write actual privacy policy (or work with legal team)
  2. Update PrivacyScreen with real content
  3. Add sections: data collection, usage, sharing, retention
  4. Add GDPR rights explanation
  5. Add contact information
  6. Run flutter analyze
  7. Test privacy screen display
- **Expected Result:** Real privacy policy displayed
- **Commit Message:** "Add complete privacy policy content"

#### Task 19.4: Add Cookie/Consent Management
- **File:** Create consent handling
- **Steps:**
  1. Create consent dialog for first launch
  2. Store consent preferences
  3. Allow users to change consent in settings
  4. Implement analytics opt-out if needed
  5. Run flutter analyze
  6. Test consent flow
- **Expected Result:** GDPR consent management
- **Commit Message:** "Add GDPR consent management for data collection"

---

## FINAL TASKS

### Task 20.1: Documentation

#### Create README.md
- **File:** `/home/user/raw/README.md`
- **Steps:**
  1. Add project description
  2. Add features list
  3. Add setup instructions
  4. Add development guide
  5. Add testing guide
  6. Add deployment guide
  7. Add architecture overview
  8. Add contributing guidelines
- **Commit Message:** "Add comprehensive README documentation"

#### Add Code Documentation
- **Files:** All service files
- **Steps:**
  1. Add class-level documentation to all services
  2. Add method-level documentation
  3. Add parameter documentation
  4. Add example usage in comments
  5. Run flutter analyze
- **Commit Message:** "Add comprehensive code documentation"

### Task 20.2: Final Testing & Cleanup

#### Run Full Test Suite
- **Steps:**
  1. Run flutter test
  2. Verify all tests pass
  3. Check code coverage (aim for >80%)
  4. Fix any failing tests
- **Commit Message:** "Verify all tests pass with >80% coverage"

#### Run Flutter Analyze
- **Steps:**
  1. Run flutter analyze
  2. Fix all errors
  3. Fix all warnings
  4. Address linter suggestions
- **Commit Message:** "Fix all analyzer warnings and errors"

#### Remove Unused Code
- **Steps:**
  1. Search for unused imports
  2. Search for unused variables
  3. Search for dead code
  4. Remove all unused code
  5. Run flutter analyze
- **Commit Message:** "Remove all unused code and imports"

#### Performance Profiling
- **Steps:**
  1. Run app in profile mode
  2. Use Flutter DevTools
  3. Profile memory usage
  4. Profile CPU usage
  5. Check for any remaining issues
  6. Document performance metrics
- **Commit Message:** "Performance profiling complete - all metrics within acceptable range"

### Task 20.3: Production Preparation

#### Update Firebase Security Rules for Production
- **Steps:**
  1. Review firestore.rules
  2. Review storage.rules
  3. Ensure all rules are production-ready
  4. Deploy to production
  5. Test with production Firebase project
- **Commit Message:** "Update Firebase security rules for production deployment"

#### Environment Configuration
- **Steps:**
  1. Setup production Firebase config
  2. Setup staging environment
  3. Add environment switching
  4. Test in all environments
- **Commit Message:** "Add production and staging environment configuration"

#### Final Security Audit
- **Steps:**
  1. Review all authentication flows
  2. Review all authorization checks
  3. Review all input validation
  4. Review all security rules
  5. Run security scanning tools
  6. Fix any issues found
- **Commit Message:** "Complete final security audit and fix remaining issues"

---

## COMPLETION CHECKLIST

Use this checklist to track overall progress:

### Phase 1: Security & Bugs ✅
- [ ] Firestore security rules fixed
- [ ] Authorization checks added to all services
- [ ] Stream subscriptions properly disposed
- [ ] TextEditingController leaks fixed
- [ ] Force unwrapping fixed with null checks
- [ ] Mounted checks added
- [ ] Dispose methods added to all screens
- [ ] Input validation implemented
- [ ] Email verification added
- [ ] Test code removed

### Phase 2: Performance ✅
- [ ] O(n²) algorithm fixed
- [ ] N+1 queries fixed in getFriends
- [ ] N+1 queries fixed in getGroupMembers
- [ ] Firestore indexes created
- [ ] Search debouncing implemented
- [ ] Pagination added
- [ ] Real-time sync implemented
- [ ] Image size constraints added
- [ ] Image compression added
- [ ] Timer rebuilds optimized
- [ ] ListView itemExtent added
- [ ] Parallel loading implemented
- [ ] Graph calculations cached

### Phase 3: Architecture ✅
- [ ] FocusScreen extracted
- [ ] CommunityScreen extracted
- [ ] GroupDetailsScreen extracted
- [ ] ProfileScreen extracted
- [ ] All settings screens extracted
- [ ] MainScreen extracted
- [ ] main.dart reduced to ~500 lines
- [ ] ProfileImageProvider removed
- [ ] updateShouldNotify fixed
- [ ] Rollback mechanism added
- [ ] Provider package implemented
- [ ] FocusSessionService created
- [ ] Repository pattern implemented
- [ ] Caching layer added

### Phase 4: Quality & Testing ✅
- [ ] Constants files created
- [ ] Hardcoded values replaced
- [ ] Custom exceptions created
- [ ] User-facing error messages added
- [ ] Testing infrastructure setup
- [ ] Model tests written
- [ ] Service tests written
- [ ] Widget tests written
- [ ] Integration tests written
- [ ] Account deletion implemented
- [ ] Data export implemented
- [ ] Privacy policy written
- [ ] Consent management added
- [ ] README created
- [ ] Code documentation added
- [ ] All tests passing
- [ ] All analyzer warnings fixed
- [ ] Unused code removed
- [ ] Performance profiling complete
- [ ] Production security rules deployed
- [ ] Environment configuration complete
- [ ] Final security audit complete

---

## SUCCESS METRICS

After completing all tasks, verify these improvements:

### Performance Metrics
- [ ] Friend list loading: 5s → 500ms (10x faster)
- [ ] Group members loading: 3s → 300ms (10x faster)
- [ ] Search queries: 7 → 1 (7x reduction)
- [ ] Firestore costs: 90% reduction
- [ ] Memory per image: 50MB → 1MB (98% reduction)
- [ ] Frame rate: Consistent 60 FPS

### Code Quality Metrics
- [ ] main.dart: 9,505 lines → ~500 lines
- [ ] Test coverage: >80%
- [ ] Zero analyzer warnings
- [ ] Zero memory leaks
- [ ] Zero force unwraps without checks

### Security Metrics
- [ ] All Firestore rules restrict access by ownership
- [ ] All services check authorization
- [ ] All inputs validated
- [ ] Email verification required
- [ ] No test credentials in code

---

## NOTES FOR CLAUDE CODE

### When Working Through This Plan:
1. **Always read files before editing** - Use Read tool first
2. **Test after each task** - Run flutter analyze and manual testing
3. **Commit atomically** - One task = one commit
4. **Ask for clarification** - If anything is unclear, ask the user
5. **Report progress** - Update the user after completing each task
6. **Handle blockers** - If stuck, explain the issue and ask for guidance
7. **Preserve functionality** - Never break existing features
8. **Document changes** - Clear commit messages and code comments

### Git Workflow:
1. Work on branch: `claude/audit-code-improvements-011CUpFR5ckY9BaNSMfP6U7x`
2. Commit after each task
3. Push regularly (every 5-10 commits)
4. Create PR when phase complete

### Testing Checklist After Each Task:
1. Run `flutter analyze` - must pass with no errors
2. Run `flutter test` - all tests must pass
3. Manual test affected features
4. Check for regressions
5. Verify performance if applicable

---

## ESTIMATED TIMELINE

| Phase | Duration | Tasks |
|-------|----------|-------|
| Phase 1: Security & Bugs | 4-5 weeks | 30 tasks |
| Phase 2: Performance | 3-4 weeks | 20 tasks |
| Phase 3: Architecture | 4-6 weeks | 25 tasks |
| Phase 4: Quality & Testing | 3-4 weeks | 25 tasks |
| **Total** | **17-25 weeks** | **100 tasks** |

---

**This plan is comprehensive and production-ready. Follow it step by step, and the RAW app will be secure, performant, maintainable, and production-ready.**

**Good luck, Claude Code! 🚀**
