import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../controller/seller_registration/cubit.dart';
import '../controller/customer_registration/cubit.dart';
import '../controller/login/cubit.dart';
import '../controller/otp_verification/cubit.dart';
import '../controller/profile/cubit.dart';
import '../controller/logout/cubit.dart';
import '../controller/auth_session/cubit.dart';
import '../controller/profile_edit/cubit.dart';
import '../controller/add_product/cubit.dart';
import '../controller/seller_products/cubit.dart';
import '../controller/product_favorite/cubit.dart';
import '../controller/product_rating/cubit.dart';
import '../controller/product_report/cubit.dart';
import '../controller/password_change/cubit.dart';
import '../controller/forgot_password/cubit.dart';
import '../controller/product_reviews/cubit.dart';
import '../controller/customer_favorites/cubit.dart';
import '../controller/admin_reported_products/cubit.dart';
import '../controller/admin_sellers/cubit.dart';
import '../controller/admin_requests/cubit.dart';
import '../controller/admin_seller_products/cubit.dart';
import '../controller/products/cubit.dart';

class AppBlocProvider extends StatelessWidget {
  final Widget child;

  const AppBlocProvider({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthSessionCubit()),
        BlocProvider(create: (_) => SellerRegistrationCubit()),
        BlocProvider(create: (_) => CustomerRegistrationCubit()),
        BlocProvider(create: (_) => LoginCubit()),
        BlocProvider(create: (_) => OtpVerificationCubit()),
        BlocProvider(create: (_) => ProfileCubit()),
        BlocProvider(create: (_) => ProfileEditCubit()),
        BlocProvider(
          create: (context) => LogoutCubit(context.read<ProfileCubit>()),
        ),
        BlocProvider(create: (_) => AddProductCubit()),
        BlocProvider(create: (_) => SellerProductsCubit()),
        BlocProvider(create: (_) => ProductFavoriteCubit()),
        BlocProvider(create: (_) => ProductRatingCubit()),
        BlocProvider(create: (_) => ProductReportCubit()),
        BlocProvider(create: (_) => PasswordChangeCubit()),
        BlocProvider(create: (_) => ForgotPasswordCubit()),
        BlocProvider(create: (_) => ProductReviewsCubit()),
        BlocProvider(create: (_) => CustomerFavoritesCubit()),
        BlocProvider(create: (_) => AdminReportedProductsCubit()),
        BlocProvider(create: (_) => AdminSellersCubit()),
        BlocProvider(create: (_) => AdminRequestsCubit()),
        BlocProvider(create: (_) => AdminSellerProductsCubit()),
        BlocProvider(create: (_) => ProductsCubit()),
      ],
      child: child,
    );
  }
}

