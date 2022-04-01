//===========================================================================
namespace a_ns {                   // for namespace testing
   extern int g_g;
   int get_g_g();

   struct g_class {
      g_class() { m_g = -7; }
      int m_g;
      static int s_g;

      struct h_class {
         h_class() { m_h = -8; }
         int m_h;
         static int s_h;
      };
   };

   namespace d_ns {
      extern int g_i;
      int get_g_i();

      struct i_class {
         i_class() { m_i = -9; }
         int m_i;
         static int s_i;

         struct j_class {
            j_class() { m_j = -10; }
            int m_j;
            static int s_j;
         };
      };

   } // namespace d_ns

} // namespace a_ns
