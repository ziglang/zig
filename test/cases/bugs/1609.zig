test "" {
    failed: {
        inline for ([]void{{},{}}) |_| {
            var a = false;

            if (a)
                break :failed;
            if (a)
                break :failed;
        }
    }
}
