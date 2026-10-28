// Widget tests for the SkillDad mobile app.
//
// All network calls go through AuthService/ContentService, which accept an
// injectable http.Client - tests replace `.instance` with one backed by a
// MockClient so results are deterministic and never touch the real
// production API.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skilldad_mobile/main.dart';
import 'package:skilldad_mobile/screens/career_path_screen.dart';
import 'package:skilldad_mobile/screens/courses_catalog_screen.dart';
import 'package:skilldad_mobile/screens/university_detail_screen.dart';
import 'package:skilldad_mobile/services/auth_service.dart';
import 'package:skilldad_mobile/services/content_service.dart';
import 'package:skilldad_mobile/services/dashboard_service.dart';
import 'package:skilldad_mobile/services/jobs_service.dart';
import 'package:skilldad_mobile/services/course_player_service.dart';
import 'package:skilldad_mobile/services/discussion_service.dart';
import 'package:skilldad_mobile/services/exam_service.dart';
import 'package:skilldad_mobile/services/notification_service.dart';
import 'package:skilldad_mobile/services/profile_service.dart';
import 'package:skilldad_mobile/services/referral_service.dart';
import 'package:skilldad_mobile/services/study_abroad_service.dart';

void main() {
  // The Home, Login and Register screens are all taller than flutter_test's
  // default 800x600 surface, so give every test a realistic phone-sized
  // viewport instead.
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SkillDadApp());
  }

  setUp(() {
    // No persisted session and no real network calls in any test by
    // default; individual tests override AuthService/ContentService's
    // MockClient behaviour where they need a specific response.
    SharedPreferences.setMockInitialValues({});
    AuthService.instance = AuthService(
      client: MockClient((request) async => http.Response('{}', 500)),
    );
    ContentService.instance = ContentService(
      client: MockClient((request) async => http.Response('[]', 200)),
    );
    // Every dashboard endpoint returns empty by default; individual tests
    // override this where they need specific dashboard content.
    DashboardService.instance = DashboardService(
      client: MockClient(
        (request) async =>
            http.Response(request.method == 'POST' ? '{}' : '[]', 200),
      ),
    );
    // No open vacancies and no applications by default; the Jobs test
    // overrides this with real-shaped vacancy data.
    JobsService.instance = JobsService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({'success': true, 'vacancies': [], 'applications': []}),
          200,
        ),
      ),
    );
    // No exams by default; the exam tests override this with real-shaped data.
    ExamService.instance = ExamService(
      client: MockClient(
        (request) async => http.Response(jsonEncode({'success': true, 'data': []}), 200),
      ),
    );
    // No discussion messages by default under any lesson.
    DiscussionService.instance = DiscussionService(
      client: MockClient((request) async => http.Response('[]', 200)),
    );
    // No profile/referral data by default; the Profile test overrides this
    // with real-shaped data.
    ProfileService.instance = ProfileService(
      client: MockClient((request) async => http.Response('{}', 500)),
    );
    ReferralService.instance = ReferralService(
      client: MockClient((request) async => http.Response('{}', 500)),
    );
    // No notifications by default; the dashboard/notifications tests
    // override this with real-shaped data where relevant.
    NotificationService.instance = NotificationService(
      client: MockClient((request) async => http.Response('[]', 200)),
    );
  });

  Future<void> openLogin(WidgetTester tester) async {
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
  }

  testWidgets('Home screen loads with the core landing sections', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Confusion to'), findsOneWidget);
    expect(find.text('More Reasons to Choose SkillDad'), findsOneWidget);
    expect(find.text('Your Career\nOur Mission'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('Explore Courses opens the real public course catalog', (
    WidgetTester tester,
  ) async {
    ContentService.instance = ContentService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode([
            {
              'title': 'Hospital Administration',
              'description': 'Real course from the live catalog.',
              'thumbnail': '/uploads/thumbnail-1.jpg',
              'programType': 'course',
              'isFeatured': true,
            },
          ]),
          200,
        ),
      ),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Explore Courses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore Courses'));
    await tester.pumpAndSettle();

    // Landed on the Courses catalog screen, not scrolled within Home.
    expect(find.text('Build Skills,'), findsNothing);
    expect(find.text('Hospital Administration'), findsOneWidget);
  });

  testWidgets('Featured Courses View All button opens public course catalog', (
    WidgetTester tester,
  ) async {
    ContentService.instance = ContentService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode([
            {
              'title': 'Hospital Administration',
              'description': 'Real course from the live catalog.',
              'thumbnail': '/uploads/thumbnail-1.jpg',
              'programType': 'course',
              'isFeatured': true,
            },
          ]),
          200,
        ),
      ),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();

    final viewAllBtn = find.text('View All');
    await tester.ensureVisible(viewAllBtn);
    await tester.pumpAndSettle();
    await tester.tap(viewAllBtn);
    await tester.pumpAndSettle();

    expect(find.byType(CoursesCatalogScreen), findsOneWidget);
    expect(find.text('Hospital Administration'), findsOneWidget);
  });

  testWidgets('Tapping a course opens its real public detail page', (
    WidgetTester tester,
  ) async {
    ContentService.instance = ContentService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/api/courses/course_1')) {
          return http.Response(
            jsonEncode({
              'id': 'course_1',
              'title': 'Hospital Administration',
              'description': 'Learn real hospital administration skills.',
              'thumbnail': '/uploads/thumbnail-1.jpg',
              'category': 'Healthcare',
              'price': '0',
              'instructor_name': 'Dr. Ramiz Zekaj',
              'university_name': 'Manipal University Jaipur',
              'modules': [
                {
                  '_id': 'module_1',
                  'title': 'Introduction',
                  'videos': [
                    {'_id': 'video_1', 'title': 'Class 1'},
                  ],
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode([
            {
              'id': 'course_1',
              'title': 'Hospital Administration',
              'description': 'Real course from the live catalog.',
              'thumbnail': '/uploads/thumbnail-1.jpg',
              'programType': 'course',
              'isFeatured': true,
            },
          ]),
          200,
        );
      }),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Explore Courses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore Courses'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hospital Administration'));
    await tester.pumpAndSettle();

    // Real public detail content, not enrolled (no session) - "Enroll Now".
    expect(find.text('Learn real hospital administration skills.'), findsOneWidget);
    expect(find.text('Dr. Ramiz Zekaj'), findsOneWidget);
    expect(find.text('Manipal University Jaipur'), findsOneWidget);
    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('Enroll Now'), findsOneWidget);

    // Not signed in - tapping it should prompt sign-in rather than fail silently.
    await tester.tap(find.text('Enroll Now'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('Course detail page still offers a way back and a retry if it fails to load', (
    WidgetTester tester,
  ) async {
    ContentService.instance = ContentService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/api/courses/course_1')) {
          return http.Response('Server error', 500);
        }
        return http.Response(
          jsonEncode([
            {
              'id': 'course_1',
              'title': 'Hospital Administration',
              'thumbnail': '',
              'programType': 'course',
              'isFeatured': true,
            },
          ]),
          200,
        );
      }),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Explore Courses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore Courses'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hospital Administration'));
    await tester.pumpAndSettle();

    // The failed-to-load state must never trap the student on a bare
    // spinner/error with no way out - a back button and a retry are both
    // present.
    expect(find.text("Couldn't load this course. Check your connection and try again."), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Courses'), findsOneWidget);
  });

  testWidgets('Course catalog category tabs filter by the real program type', (
    WidgetTester tester,
  ) async {
    ContentService.instance = ContentService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode([
            {
              'title': 'Hospital Administration',
              'description': 'A skill course.',
              'thumbnail': '/uploads/thumbnail-1.jpg',
              'programType': 'course',
            },
            {
              'title': 'MBA in Hospital Administration',
              'description': 'A skill integrated diploma.',
              'thumbnail': '/uploads/thumbnail-2.jpg',
              'programType': 'degree_programme',
            },
            {
              'title': 'Work Based Learning - Germany',
              'description': 'A WBL programme.',
              'thumbnail': '/uploads/thumbnail-3.jpg',
              'programType': 'wbl_abroad',
            },
          ]),
          200,
        ),
      ),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Explore Courses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore Courses'));
    await tester.pumpAndSettle();

    // All three appear under "All Courses".
    expect(find.text('Hospital Administration'), findsOneWidget);
    expect(find.text('MBA in Hospital Administration'), findsOneWidget);
    expect(find.text('Work Based Learning - Germany'), findsOneWidget);

    await tester.dragUntilVisible(
      find.textContaining('WBL (Work Based Learning)'),
      find.byType(ListView).first,
      const Offset(-150, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('WBL (Work Based Learning)'));
    await tester.pumpAndSettle();

    expect(find.text('Work Based Learning - Germany'), findsOneWidget);
    expect(find.text('Hospital Administration'), findsNothing);
    expect(find.text('MBA in Hospital Administration'), findsNothing);

    // WBL defaults to International; switching to Domestic shows the
    // real domestic programme and hides the international one.
    expect(find.text('International Programmes'), findsOneWidget);
    expect(find.text('Domestic Programmes'), findsOneWidget);
    await tester.tap(find.text('Domestic Programmes'));
    await tester.pumpAndSettle();
    expect(find.text('Work Based Learning - Germany'), findsNothing);
  });

  testWidgets('Study Abroad opens the real country drill-down', (
    WidgetTester tester,
  ) async {
    ContentService.instance = ContentService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode([
            {
              'title': 'Hospital Administration',
              'description': 'A skill course.',
              'thumbnail': '/uploads/thumbnail-1.jpg',
              'programType': 'course',
            },
          ]),
          200,
        ),
      ),
    );
    StudyAbroadService.instance = StudyAbroadService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode([
            {
              'id': 'country_1',
              'name': 'Albania',
              'image_url': '',
              'description': 'A beautiful European country.',
            },
          ]),
          200,
        ),
      ),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Explore Courses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore Courses'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Study Abroad'),
      find.byType(ListView).first,
      const Offset(-150, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Study Abroad'));
    await tester.pumpAndSettle();

    expect(find.text('Albania'), findsOneWidget);
    expect(find.text('Choose a country to see partner universities and their programmes.'), findsOneWidget);
  });

  testWidgets('Footer Quick Links open the real matching destinations', (
    WidgetTester tester,
  ) async {
    ContentService.instance = ContentService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode([
            {
              'title': 'Hospital Administration',
              'description': 'Real featured course from the live API.',
              'thumbnail': '/uploads/thumbnail-1.jpg',
              'programType': 'course',
              'isFeatured': true,
            },
          ]),
          200,
        ),
      ),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();

    // Sanity check: the featured course itself should already be rendered
    // before we even touch the footer link.
    expect(find.text('Hospital Administration'), findsOneWidget);

    final coursesLink = find.byKey(const ValueKey('footer_link_Courses'));
    await tester.ensureVisible(coursesLink);
    await tester.pumpAndSettle();
    await tester.tap(coursesLink);
    await tester.pumpAndSettle();

    // "Courses" now opens the real public catalog screen, not a scroll.
    expect(find.text('Hospital Administration'), findsOneWidget);
    expect(find.text('Build Skills,'), findsNothing);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    final universitiesLink = find.byKey(const ValueKey('footer_link_Universities'));
    await tester.ensureVisible(universitiesLink);
    await tester.pumpAndSettle();
    await tester.tap(universitiesLink);
    await tester.pumpAndSettle();

    expect(find.text('Partner Universities'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    final partnersLink = find.byKey(const ValueKey('footer_link_Partners'));
    await tester.ensureVisible(partnersLink);
    await tester.pumpAndSettle();
    await tester.tap(partnersLink);
    await tester.pumpAndSettle();
    expect(find.text('Trusted by Leading Universities\n& Companies'), findsOneWidget);

    final contactLink = find.byKey(const ValueKey('footer_link_Contact'));
    await tester.ensureVisible(contactLink);
    await tester.pumpAndSettle();
    await tester.tap(contactLink);
    await tester.pumpAndSettle();

    expect(find.text('Contact SkillDad'), findsOneWidget);
    expect(find.text('+91 8448119306'), findsOneWidget);
    expect(find.text('skilldad12@gmail.com'), findsOneWidget);
  });

  testWidgets('Home shows no fabricated course listing or testimonial', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();

    // The mocked ContentService returns an empty list, so the featured
    // courses section (which hides itself when there's nothing featured,
    // matching the real website) shouldn't render fabricated placeholders.
    expect(find.textContaining('Priya'), findsNothing);
    expect(find.textContaining('helped me build'), findsNothing);
    expect(find.text('Hospital Administration'), findsNothing);

    // Leadership falls back to the real, static director list when the
    // live call fails/returns nothing for the landing page.
    expect(find.text('Prof. Dr. Ramiz Zekaj'), findsOneWidget);
  });

  testWidgets('A restored session on Home shows a real Dashboard button that opens the dashboard', (
    WidgetTester tester,
  ) async {
    // Simulate the app reopening with an already-signed-in student (a
    // persisted session, not a fresh login) - the Home hero CTA should
    // offer a real way back into the dashboard, not just sign out.
    SharedPreferences.setMockInitialValues({
      'skilldad_auth_user': jsonEncode({
        '_id': 'user_1',
        'name': 'Rinsha Ali',
        'email': 'rinsha@skilldad.com',
        'role': 'student',
        'token': 'test-token',
      }),
    });

    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Sign out'), findsOneWidget);
    expect(find.text('Hi, Rinsha'), findsNothing);

    // The hero CTA swaps to "Go to Dashboard" for a signed-in student
    // instead of "Explore Courses" - the one way back into the dashboard
    // (the top bar no longer duplicates it).
    expect(find.text('Go to Dashboard'), findsOneWidget);
    expect(find.text('Explore Courses'), findsNothing);

    await tester.tap(find.text('Go to Dashboard'));
    await tester.pumpAndSettle();

    // Landed on the real student dashboard, not just a snackbar/no-op.
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

    // Tapping the logo there is a real way back to the public landing page -
    // not a no-op, since Dashboard is the root route after sign-in.
    await tester.tap(find.text('SKILLDAD'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Confusion to'), findsOneWidget);
  });

  testWidgets('Sign In button opens the login screen', (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();

    await openLogin(tester);

    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Enter your registered email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);

    // Password is hidden by default and can be toggled visible.
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('Tapping the SkillDad logo on Login returns to the landing page', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);

    // No back button on Login any more - the logo is the way home.
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);

    await tester.tap(find.text('SKILLDAD'));
    await tester.pumpAndSettle();

    expect(find.text('Confusion to'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);
  });

  testWidgets('Sign In shows validation errors on empty submit', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your registered email'), findsWidgets);
    expect(find.text('Enter your password'), findsWidgets);
  });

  testWidgets('Forgot password sends a real reset request and shows the server message', (
    WidgetTester tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        expect(request.url.path, endsWith('/api/users/forgotpassword'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'student@skilldad.com');
        return http.Response(
          jsonEncode({'success': true, 'message': 'Recovery link dispatched to your inbox'}),
          200,
        );
      }),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your registered email'),
      'student@skilldad.com',
    );
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset your password'), findsOneWidget);
    // The dialog's own email field is pre-filled from the login form -
    // the same address now shows in both the login field and the dialog.
    expect(find.text('student@skilldad.com'), findsWidgets);

    await tester.tap(find.text('Send link'));
    await tester.pumpAndSettle();

    expect(find.text('Recovery link dispatched to your inbox'), findsOneWidget);
  });

  testWidgets('Sign In shows the API error message on invalid credentials', (
    WidgetTester tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient(
        (request) async =>
            http.Response(jsonEncode({'message': 'Invalid email or password'}), 401),
      ),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your registered email'),
      'student@skilldad.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'wrongpassword',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password'), findsOneWidget);
    // Still on the login screen - a failed sign-in never navigates away.
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('Sign In with valid credentials opens the student dashboard', (
    WidgetTester tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            '_id': 'user_1',
            'name': 'Asha Verma',
            'email': 'asha@skilldad.com',
            'role': 'student',
            'token': 'test-token',
          }),
          200,
        ),
      ),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your registered email'),
      'asha@skilldad.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'correct-password',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Landed on the dashboard, not back on the marketing Home screen.
    expect(find.text('Keep Learning,\nKeep Growing'), findsOneWidget);
    expect(find.text('Hello, Asha 👋'), findsOneWidget);
    expect(find.text('Build Skills,'), findsNothing);
    expect(find.text('Sign In'), findsNothing);
  });

  testWidgets('Dashboard shows real course/career data and no fabricated content', (
    WidgetTester tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            '_id': 'user_1',
            'name': 'Asha Verma',
            'email': 'asha@skilldad.com',
            'role': 'student',
            'token': 'test-token',
          }),
          200,
        ),
      ),
    );
    DashboardService.instance = DashboardService(
      client: MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST') return http.Response('{}', 200);
        if (path.endsWith('/enrollment/my-courses')) {
          return http.Response(
            jsonEncode([
              {
                'course': {
                  '_id': 'course_1',
                  'title': 'Hospital Administration',
                  'thumbnail': '/uploads/thumbnail-1784877473540.jpg',
                },
                'progress': 60,
              },
            ]),
            200,
          );
        }
        if (path.endsWith('/students/performance/weekly')) {
          return http.Response(
            jsonEncode([
              {'name': 'Mon', 'value': 20},
              {'name': 'Tue', 'value': 45},
            ]),
            200,
          );
        }
        if (path.endsWith('/users/me/career-progress')) {
          return http.Response(
            jsonEncode({'careerGoal': 'Hospital Administrator', 'interviewPrepCompleted': true}),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your registered email'),
      'asha@skilldad.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'correct-password',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Real enrolled course and career goal, from the mocked live API.
    expect(find.text('Hospital Administration'), findsOneWidget);
    expect(find.text('60%'), findsWidgets);
    expect(find.text('Continue Learning'), findsOneWidget);
    expect(find.text('Your Career Journey'), findsOneWidget);

    // Never a fabricated testimonial-style name/quote.
    expect(find.textContaining('Priya'), findsNothing);
    expect(find.textContaining('helped me build'), findsNothing);
  });

  testWidgets('Notification bell opens the real list and mark-all-read updates the badge', (
    WidgetTester tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            '_id': 'user_1',
            'name': 'Asha Verma',
            'email': 'asha@skilldad.com',
            'role': 'student',
            'token': 'test-token',
          }),
          200,
        ),
      ),
    );
    var markedRead = false;
    NotificationService.instance = NotificationService(
      client: MockClient((request) async {
        if (request.method == 'PUT' && request.url.path.endsWith('/api/notifications/read')) {
          markedRead = true;
          return http.Response(jsonEncode({'success': true}), 200);
        }
        if (request.url.path.endsWith('/api/notifications/my')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'notif_1',
                'type': 'enrollment',
                'message': '',
                'metadata': {'courseTitle': 'Hospital Administration'},
                'created_at': DateTime.now().toIso8601String(),
                'is_read': false,
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your registered email'),
      'asha@skilldad.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'correct-password',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Real unread badge on the bell icon, driven by the real unread log.
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('✅ Enrollment Confirmed'), findsOneWidget);
    expect(find.text('You have been enrolled in Hospital Administration'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(markedRead, isTrue);
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('Courses bottom-nav tab opens the real enrolled-course list', (
    WidgetTester tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            '_id': 'user_1',
            'name': 'Asha Verma',
            'email': 'asha@skilldad.com',
            'role': 'student',
            'token': 'test-token',
          }),
          200,
        ),
      ),
    );
    DashboardService.instance = DashboardService(
      client: MockClient((request) async {
        if (request.method == 'POST') return http.Response('{}', 200);
        if (request.url.path.endsWith('/enrollment/my-courses')) {
          return http.Response(
            jsonEncode([
              {
                'course': {
                  '_id': 'course_1',
                  'title': 'Hospital Administration',
                  'thumbnail': '/uploads/thumbnail-1784877473540.jpg',
                },
                'progress': '60',
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your registered email'),
      'asha@skilldad.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'correct-password',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // "Courses" is the bottom nav's raised center FAB - icon-only, no label.
    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pumpAndSettle();

    expect(find.text('My Courses'), findsWidgets);
    expect(find.text('Hospital Administration'), findsOneWidget);
  });

  testWidgets('Tapping an enrolled course opens the real lesson player and marks progress', (
    WidgetTester tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            '_id': 'user_1',
            'name': 'Asha Verma',
            'email': 'asha@skilldad.com',
            'role': 'student',
            'token': 'test-token',
          }),
          200,
        ),
      ),
    );
    DashboardService.instance = DashboardService(
      client: MockClient((request) async {
        if (request.method == 'POST') return http.Response('{}', 200);
        if (request.url.path.endsWith('/enrollment/my-courses')) {
          return http.Response(
            jsonEncode([
              {
                'course': {
                  '_id': 'course_1',
                  'title': 'Hospital Administration',
                  'thumbnail': '/uploads/thumbnail-1784877473540.jpg',
                },
                'progress': '60',
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );
    CoursePlayerService.instance = CoursePlayerService(
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          return http.Response(jsonEncode({'progress': 75}), 200);
        }
        if (request.url.path.endsWith('/api/enrollment/my-courses')) {
          return http.Response(
            jsonEncode([
              {
                'course': {'_id': 'course_1'},
                'completedVideos': [],
                'completedExercises': [],
              },
            ]),
            200,
          );
        }
        if (request.url.path.endsWith('/api/courses/course_1')) {
          return http.Response(
            jsonEncode({
              'title': 'Hospital Administration',
              'modules': [
                {
                  '_id': 'module_1',
                  'title': 'Introduction',
                  'videos': [
                    {
                      '_id': 'video_1',
                      'title': 'Class 1',
                      'url': 'https://www.youtube.com/watch?v=abc123',
                      'duration': '10 min',
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your registered email'),
      'asha@skilldad.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'correct-password',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hospital Administration'));
    await tester.pumpAndSettle();

    // Real course content loaded from the live API.
    expect(find.text('Introduction'), findsOneWidget);
    await tester.tap(find.text('Introduction'));
    await tester.pumpAndSettle();

    expect(find.text('Class 1'), findsOneWidget);
    expect(find.text('Mark Watched'), findsOneWidget);

    await tester.tap(find.text('Mark Watched'));
    await tester.pumpAndSettle();

    // Once marked, the button disappears and a check mark shows instead.
    expect(find.text('Mark Watched'), findsNothing);

    // The real Discussion Hub under this lesson - one existing message from
    // another student, plus posting a new one and liking it.
    var discussionPosted = false;
    var likeToggled = false;
    DiscussionService.instance = DiscussionService(
      client: MockClient((request) async {
        if (request.method == 'GET' && request.url.path.contains('/api/discussions/course_1/video_1')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'disc_1',
                'user_id': 'user_2',
                'user_name': 'Ravi Kumar',
                'content': 'Great explanation of the admission process!',
                'created_at': '2026-01-05T10:00:00.000Z',
                'liked_by': [],
              },
            ]),
            200,
          );
        }
        if (request.method == 'POST' && request.url.path.endsWith('/api/discussions')) {
          discussionPosted = true;
          return http.Response(
            jsonEncode({
              'id': 'disc_2',
              'user_id': 'user_1',
              'user_name': 'Asha Verma',
              'content': 'What are the eligibility criteria?',
              'created_at': '2026-01-05T11:00:00.000Z',
              'liked_by': [],
            }),
            201,
          );
        }
        if (request.method == 'PUT' && request.url.path.endsWith('/like')) {
          likeToggled = true;
          return http.Response(jsonEncode({'likedBy': ['user_1']}), 200);
        }
        return http.Response('[]', 200);
      }),
    );

    // "Watch" opens the real lesson in-app instead of leaving the app.
    await tester.tap(find.text('Watch'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('Class 1'), findsWidgets);

    // Scroll the lesson panel down to reveal the real Discussion Hub below
    // the watch/exercise buttons.
    await tester.dragUntilVisible(
      find.text('Discussion Hub'),
      find.byType(SingleChildScrollView).last,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('Great explanation of the admission process!'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Write your thought or question here...'),
      'What are the eligibility criteria?',
    );
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(discussionPosted, isTrue);
    expect(find.text('What are the eligibility criteria?'), findsOneWidget);

    await tester.tap(find.text('Like').first);
    await tester.pumpAndSettle();

    expect(likeToggled, isTrue);
  });

  testWidgets('Exercise shows the real question as an interactive quiz and reports score', (
    WidgetTester tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            '_id': 'user_1',
            'name': 'Asha Verma',
            'email': 'asha@skilldad.com',
            'role': 'student',
            'token': 'test-token',
          }),
          200,
        ),
      ),
    );
    DashboardService.instance = DashboardService(
      client: MockClient((request) async {
        if (request.method == 'POST') return http.Response('{}', 200);
        if (request.url.path.endsWith('/enrollment/my-courses')) {
          return http.Response(
            jsonEncode([
              {
                'course': {'_id': 'course_1', 'title': 'Hospital Administration'},
                'progress': '60',
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );
    var exerciseScoreSubmitted = false;
    CoursePlayerService.instance = CoursePlayerService(
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['exerciseScore'] == 100) exerciseScoreSubmitted = true;
          return http.Response(jsonEncode({'progress': 80}), 200);
        }
        if (request.url.path.endsWith('/api/enrollment/my-courses')) {
          return http.Response(jsonEncode([]), 200);
        }
        if (request.url.path.endsWith('/api/courses/course_1')) {
          return http.Response(
            jsonEncode({
              'title': 'Hospital Administration',
              'modules': [
                {
                  '_id': 'module_1',
                  'title': 'Introduction',
                  'videos': [
                    {
                      '_id': 'video_1',
                      'title': 'Class 1',
                      'url': 'https://www.youtube.com/watch?v=abc123',
                      'exercises': [
                        {
                          'question': 'According to WHO, medical care should primarily aim to:',
                          'options': ['Treat diseases after they occur', 'Promote and maintain health'],
                          'correctAnswer': 'Promote and maintain health',
                        },
                      ],
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your registered email'),
      'asha@skilldad.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'correct-password',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hospital Administration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Introduction'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark Watched'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Take Exercise'));
    await tester.pumpAndSettle();

    // Real question, lettered interactive options (not a plain radio list).
    expect(find.textContaining('According to WHO, medical care should primarily aim to:'), findsOneWidget);
    expect(find.textContaining('a. Treat diseases after they occur'), findsOneWidget);
    expect(find.textContaining('b. Promote and maintain health'), findsOneWidget);
    expect(exerciseScoreSubmitted, isFalse);

    // Pick the real correct answer and move to the result summary.
    await tester.tap(find.textContaining('Promote and maintain health'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See Result'));
    await tester.pumpAndSettle();

    // Real score summary (1/1 correct = 100%), then saving it finalizes progress.
    expect(find.text('1 / 1 correct · 100%'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(exerciseScoreSubmitted, isTrue);
    expect(find.text('Exercise Passed'), findsOneWidget);
  });

  testWidgets('Upcoming exam opens the real exam-taking flow and shows the real result', (
    WidgetTester tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            '_id': 'user_1',
            'name': 'Asha Verma',
            'email': 'asha@skilldad.com',
            'role': 'student',
            'token': 'test-token',
          }),
          200,
        ),
      ),
    );
    final examScheduledStart = DateTime.now().add(const Duration(minutes: 5)).toIso8601String();
    DashboardService.instance = DashboardService(
      client: MockClient((request) async {
        if (request.method == 'POST') return http.Response('{}', 200);
        if (request.url.path.endsWith('/exams/student/my-exams')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 'exam_1',
                  'title': 'Hospital Administration Midterm',
                  'status': 'scheduled',
                  'scheduledStartTime': examScheduledStart,
                },
              ],
            }),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );
    var submittedBody = <String, dynamic>{};
    ExamService.instance = ExamService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/exams/student/my-exams')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  '_id': 'exam_1',
                  'title': 'Hospital Administration Midterm',
                  'course': {'title': 'Hospital Administration'},
                  'scheduledStartTime': examScheduledStart,
                  'duration': 30,
                  'totalMarks': 1,
                  'status': 'scheduled',
                  'hasSubmitted': false,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/exam_1/start')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'submission': {'_id': 'sub_1'},
              'questions': [
                {
                  '_id': 'q_1',
                  'questionText': 'Which organ pumps blood?',
                  'questionType': 'mcq',
                  'options': [
                    {'text': 'Lungs', 'isCorrect': false},
                    {'text': 'Heart', 'isCorrect': true},
                  ],
                  'marks': 1,
                },
              ],
              'timeRemaining': 1800,
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/answer')) {
          return http.Response(jsonEncode({'success': true}), 200);
        }
        if (request.url.path.endsWith('/submit')) {
          submittedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'success': true}), 200);
        }
        if (request.url.path.endsWith('/exam/exam_1/my-submission')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'submission': {
                'obtainedMarks': 1,
                'totalMarks': 1,
                'answers': [
                  {
                    'questionId': 'q_1',
                    'selectedOption': 1,
                    'isCorrect': true,
                    'question': {
                      'questionText': 'Which organ pumps blood?',
                      'options': [
                        {'text': 'Lungs', 'isCorrect': false},
                        {'text': 'Heart', 'isCorrect': true},
                      ],
                    },
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your registered email'),
      'asha@skilldad.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'correct-password',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // The real exam shows up in the dashboard's Upcoming list - scroll it
    // into view first since the performance chart above it can push it
    // below the fold.
    expect(find.text('Hospital Administration Midterm'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Hospital Administration Midterm'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Hospital Administration Midterm'));
    await tester.pumpAndSettle();

    // Landed on the real Exams list.
    expect(find.text('Exams'), findsOneWidget);
    await tester.tap(find.text('Hospital Administration Midterm'));
    await tester.pumpAndSettle();

    // Real question from the real started exam, with a live timer.
    expect(find.textContaining('Which organ pumps blood?'), findsOneWidget);
    expect(find.textContaining(':'), findsWidgets);

    await tester.tap(find.textContaining('Heart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Exam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    // Real submit request carried the real selected answer.
    expect(submittedBody['answers'], isNotEmpty);
    expect((submittedBody['answers'] as List).first['selectedOption'], 1);

    // Real result screen with the real score and answer review.
    expect(find.text('You Passed!'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('Your answer: Heart'), findsOneWidget);
  });

  testWidgets('Resume Learning on the dashboard hero opens the real in-progress course', (
    WidgetTester tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            '_id': 'user_1',
            'name': 'Asha Verma',
            'email': 'asha@skilldad.com',
            'role': 'student',
            'token': 'test-token',
          }),
          200,
        ),
      ),
    );
    DashboardService.instance = DashboardService(
      client: MockClient((request) async {
        if (request.method == 'POST') return http.Response('{}', 200);
        if (request.url.path.endsWith('/enrollment/my-courses')) {
          return http.Response(
            jsonEncode([
              {
                'course': {'_id': 'course_1', 'title': 'Hospital Administration'},
                'progress': '60',
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );
    CoursePlayerService.instance = CoursePlayerService(
      client: MockClient((request) async {
        if (request.method == 'PUT') return http.Response(jsonEncode({'progress': 75}), 200);
        if (request.url.path.endsWith('/api/enrollment/my-courses')) {
          return http.Response(jsonEncode([]), 200);
        }
        if (request.url.path.endsWith('/api/courses/course_1')) {
          return http.Response(
            jsonEncode({
              'title': 'Hospital Administration',
              'modules': [
                {
                  '_id': 'module_1',
                  'title': 'Introduction',
                  'videos': [
                    {'_id': 'video_1', 'title': 'Class 1', 'url': 'https://www.youtube.com/watch?v=abc123'},
                  ],
                },
              ],
            }),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your registered email'),
      'asha@skilldad.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'correct-password',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Resume Learning'));
    await tester.pumpAndSettle();

    // Opened the real lesson player for the in-progress course, not nothing.
    expect(find.text('Hospital Administration'), findsOneWidget);
    expect(find.text('Introduction'), findsOneWidget);
  });

  testWidgets('Sessions bottom-nav tab opens the real session list', (
    WidgetTester tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            '_id': 'user_1',
            'name': 'Asha Verma',
            'email': 'asha@skilldad.com',
            'role': 'student',
            'token': 'test-token',
          }),
          200,
        ),
      ),
    );
    DashboardService.instance = DashboardService(
      client: MockClient((request) async {
        if (request.method == 'POST') return http.Response('{}', 200);
        if (request.url.path.endsWith('/api/sessions')) {
          return http.Response(
            jsonEncode([
              {
                'topic': 'Hospital Administration - Week 3 Q&A',
                'course': {'title': 'Hospital Administration'},
                'instructor': {'name': 'Dr. Ramiz Zekaj'},
                'startTime': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
                'duration': 45,
                'status': 'scheduled',
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your registered email'),
      'asha@skilldad.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'correct-password',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Tap the "Sessions" bottom-nav tab.
    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();

    expect(find.text('Live Sessions'), findsWidgets);
    expect(find.text('Hospital Administration - Week 3 Q&A'), findsOneWidget);
    // Real course title and instructor name, shown together on one subtitle line.
    expect(find.textContaining('Hospital Administration'), findsWidgets);
    expect(find.textContaining('Dr. Ramiz Zekaj'), findsOneWidget);
  });

  testWidgets('Jobs bottom-nav tab opens the real vacancy list and can apply', (
    WidgetTester tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            '_id': 'user_1',
            'name': 'Asha Verma',
            'email': 'asha@skilldad.com',
            'role': 'student',
            'token': 'test-token',
          }),
          200,
        ),
      ),
    );
    JobsService.instance = JobsService(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'success': true, 'message': 'Application submitted successfully.'}),
            200,
          );
        }
        if (request.url.path.endsWith('/api/career/vacancies')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'vacancies': [
                {
                  'id': 'vac_1',
                  'title': 'Data Science Intern',
                  'company': 'Microsoft',
                  'description': 'Work on cutting edge AI models for Azure.',
                  'location': 'Hybrid - Bangalore',
                  'job_type': 'Internship',
                  'salary_range': '50k/mo',
                  'deadline': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
                  'status': 'open',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/api/career/my-applications')) {
          return http.Response(jsonEncode({'success': true, 'applications': []}), 200);
        }
        return http.Response('[]', 200);
      }),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your registered email'),
      'asha@skilldad.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'correct-password',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();

    expect(find.text('Job Alerts'), findsOneWidget);
    expect(find.text('Data Science Intern'), findsOneWidget);
    expect(find.text('Microsoft'), findsOneWidget);

    await tester.tap(find.text('Apply Now'));
    await tester.pumpAndSettle();

    expect(find.text('Applied'), findsOneWidget);
  });

  testWidgets('Profile bottom-nav tab shows the real profile, streak and reward points', (
    WidgetTester tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            '_id': 'user_1',
            'name': 'Asha Verma',
            'email': 'asha@skilldad.com',
            'role': 'student',
            'token': 'test-token',
          }),
          200,
        ),
      ),
    );
    ProfileService.instance = ProfileService(
      client: MockClient((request) async {
        if (request.method == 'PUT' && request.url.path.endsWith('/api/users/profile')) {
          return http.Response(
            jsonEncode({
              '_id': 'user_1',
              'name': 'Asha Verma',
              'email': 'asha@skilldad.com',
              'bio': 'Aspiring hospital administrator.',
              'profile': {'phone': '9876500000', 'location': 'Jaipur', 'website': ''},
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/api/users/me')) {
          return http.Response(
            jsonEncode({
              '_id': 'user_1',
              'name': 'Asha Verma',
              'email': 'asha@skilldad.com',
              'bio': '',
              'profile': {'phone': '', 'location': '', 'website': ''},
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/api/users/me/career-progress')) {
          return http.Response(
            jsonEncode({
              'careerGoal': 'Hospital Administrator',
              'interviewPrepCompleted': true,
              'currentStreak': 7,
              'longestStreak': 21,
              'hasResumeUploaded': true,
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    ReferralService.instance = ReferralService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/api/referrals/my-points')) {
          return http.Response(jsonEncode({'total': 350, 'history': []}), 200);
        }
        if (request.url.path.endsWith('/api/referrals/my-code')) {
          return http.Response(
            jsonEncode({'code': 'SKD-ASHA1234', 'link': 'https://skilldad.com/register?ref=SKD-ASHA1234'}),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    DashboardService.instance = DashboardService(
      client: MockClient((request) async {
        if (request.method == 'POST') return http.Response('{}', 200);
        if (request.url.path.endsWith('/enrollment/my-courses')) {
          return http.Response(
            jsonEncode([
              {
                'course': {'_id': 'course_1', 'title': 'Hospital Administration'},
                'progress': '60',
              },
            ]),
            200,
          );
        }
        if (request.url.path.endsWith('/api/certificates/my')) {
          return http.Response(
            jsonEncode({'data': [{'status': 'ISSUED'}, {'status': 'ISSUED'}]}),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your registered email'),
      'asha@skilldad.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'correct-password',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    // Real identity.
    expect(find.text('Asha Verma'), findsOneWidget);
    expect(find.text('asha@skilldad.com'), findsOneWidget);

    // The real best streak/reward-points/referral-code feature - not demo data.
    expect(find.text('21'), findsOneWidget);
    expect(find.text('350'), findsOneWidget);
    expect(find.text('SKD-ASHA1234'), findsOneWidget);

    // Real course/certificate stats reused from the dashboard data.
    expect(find.text('1'), findsNWidgets(2)); // Enrolled Courses in card + My Courses stat
    expect(find.text('2'), findsOneWidget); // 2 issued certificates

    // Copying the referral code works.
    await tester.tap(find.text('SKD-ASHA1234'));
    await tester.pumpAndSettle();
    expect(find.text('Referral code copied'), findsOneWidget);

    // Editing the profile saves real data via PUT /api/users/profile.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Edit Profile'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'A short bio'), 'Aspiring hospital administrator.');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Aspiring hospital administrator.'), findsOneWidget);
  });

  testWidgets('Create an account navigates to the register screen', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('WhatsApp number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);

    // Back to Sign In returns to the login screen.
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('Register shows validation errors on empty submit', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('WhatsApp number is required'), findsOneWidget);
    expect(find.text('Enter a password'), findsOneWidget);
  });

  testWidgets('Register shows the API error message when the account exists', (
    WidgetTester tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient(
        (request) async =>
            http.Response(jsonEncode({'message': 'User already exists'}), 400),
      ),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'Asha Verma');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'asha@skilldad.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'WhatsApp number'),
      '9812345678',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'Str0ng!Pass',
    );
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('User already exists'), findsOneWidget);
  });

  testWidgets('Register password checklist ticks off requirements live', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'weak');
    await tester.pumpAndSettle();

    expect(find.text('SECURITY PROTOCOL'), findsOneWidget);
    // The field's own inline validator only fires on unfocus/submit now (not
    // on every keystroke), so only the checklist's unmet row is showing.
    expect(find.text('At least 8 characters'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'Str0ng!Pass',
    );
    await tester.pumpAndSettle();

    // All four requirement rows should now show the "met" check icon.
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(4));
  });

  testWidgets('Universities tile opens Universities screen and shows details', (
    WidgetTester tester,
  ) async {
    ContentService.instance = ContentService(
      client: MockClient((request) async {
        if (request.url.path.contains('/api/public/universities')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'u1',
                'name': 'Canadian Institute of Technology',
                'description': 'Premier Canadian curriculum institution in Albania.',
                'profile': {
                  'location': 'Tirana, Albania',
                  'achievements': [
                    {
                      'title': 'Institutional Accreditation by ASCAL',
                      'desc': 'Recognized by Albania Higher Education Agency.',
                    }
                  ],
                },
                'studentCount': '1,200+',
                'courseCount': '6',
                'courseTitles': ['Digital Marketing with AI'],
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();

    // Tap Universities in Quick Access
    final uniTile = find.text('Universities').first;
    await tester.ensureVisible(uniTile);
    await tester.tap(uniTile);
    await tester.pumpAndSettle();

    expect(find.text('Partner Universities'), findsOneWidget);
    expect(find.text('Canadian Institute of Technology'), findsOneWidget);
    expect(find.text('Tirana, Albania'), findsOneWidget);

    // Verify the university description is shown on the card (1-2 lines)
    expect(find.text('Premier Canadian curriculum institution in Albania.'), findsOneWidget);
    // Verify old accreditation row is removed from card
    expect(find.text('Accreditation:'), findsNothing);

    // Tap the university card to open dedicated full details screen
    await tester.tap(find.text('Canadian Institute of Technology'));
    await tester.pumpAndSettle();

    // Verify UniversityDetailScreen is pushed
    expect(find.byType(UniversityDetailScreen), findsOneWidget);
    expect(find.text('About Institution'), findsOneWidget);
    expect(find.text('Accreditations & Recognitions'), findsOneWidget);
  });

  testWidgets('Tapping View Path in dashboard career journey opens CareerPathScreen', (
    WidgetTester tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            '_id': 'user_1',
            'name': 'Asha Verma',
            'email': 'asha@skilldad.com',
            'role': 'student',
            'token': 'test-token',
          }),
          200,
        ),
      ),
    );
    DashboardService.instance = DashboardService(
      client: MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST') return http.Response('{}', 200);
        if (path.endsWith('/enrollment/my-courses')) {
          return http.Response(
            jsonEncode([
              {
                'course': {
                  '_id': 'course_1',
                  'title': 'Hospital Administration',
                  'thumbnail': '/uploads/thumbnail-1784877473540.jpg',
                },
                'progress': 60,
              },
            ]),
            200,
          );
        }
        if (path.endsWith('/students/performance/weekly')) {
          return http.Response('[]', 200);
        }
        if (path.endsWith('/users/me/career-progress')) {
          return http.Response(
            jsonEncode({'careerGoal': 'Hospital Administrator', 'interviewPrepCompleted': true}),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );

    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your registered email'),
      'asha@skilldad.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'correct-password',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Verify Dashboard loaded
    expect(find.text('Your Career Journey'), findsOneWidget);

    final viewPathBtn = find.text('View Path');
    await tester.ensureVisible(viewPathBtn);
    await tester.pumpAndSettle();
    await tester.tap(viewPathBtn);
    await tester.pumpAndSettle();

    expect(find.byType(CareerPathScreen), findsOneWidget);
    expect(find.text('Career Journey'), findsOneWidget);
    expect(find.text('Career Readiness'), findsOneWidget);
    expect(find.text('Hospital Administrator'), findsOneWidget);
    expect(find.text('STEP-BY-STEP ROADMAP'), findsOneWidget);
  });
}
